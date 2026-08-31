#!/usr/bin/env python3
"""Collect Pi provider usage records with upstream quota APIs & fast local scan.

Dual-engine collector for Omarchy shell:
1. Upstream Quota / Balance Probes:
   - DeepSeek: GET /user/balance (real-time balance)
   - OpenCode: GET /zen/go/v1/usage (rolling / weekly / monthly quota & resetsAt)
   - OpenRouter: GET /credits & /auth/key (credits & limit)
   - Google / xAI / Kimi: key validity & OAuth session token expiration probes
2. High-Performance Local Log Scanner with Mtime Cache:
   - Caches per-file stats keyed by (mtime, size) in ~/.cache/omarchy/agent-usage/.
   - Incremental refreshes take < 0.05s across 450+ sessions.

Outputs display-ready JSON records to ~/.local/state/omarchy/agents/usage/.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from pathlib import Path

COMMON_ERRORS = (
    urllib.error.URLError,
    OSError,
    json.JSONDecodeError,
    ValueError,
    KeyError,
)

PROVIDER_NAMES = {
    "deepseek": "DeepSeek",
    "google": "Google",
    "kimi-coding": "Kimi",
    "kimi": "Kimi",
    "xai": "xAI",
    "grok2api": "xAI",
    "cpa-xai": "xAI",
    "openrouter": "OpenRouter",
    "opencode-go": "OpenCode",
    "opencode": "OpenCode",
    "openai-codex": "Codex",
    "anthropic": "Claude",
}

PROVIDER_CANONICAL = {
    "grok2api": "xai",
    "cpa-xai": "xai",
    "kimi": "kimi-coding",
    "opencode-go": "opencode",
}

DEFAULT_TIERS = {
    "deepseek": "DeepSeek API",
    "google": "Gemini API",
    "kimi-coding": "Kimi API",
    "xai": "Grok API",
    "openrouter": "OpenRouter",
    "opencode": "OpenCode API",
    "openai-codex": "Codex",
}

CACHE_VERSION = 3
USAGE_RE = re.compile(r'"usage":\s*(\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\})')
PROV_RE = re.compile(r'"provider":\s*"([^"]+)"')
MODEL_RE = re.compile(r'"model":\s*"([^"]+)"')
TS_RE = re.compile(r'"timestamp":\s*"([^"]+)"')


def get_usage_dir() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local" / "state")
    usage_dir = Path(state_home) / "omarchy" / "agents" / "usage"
    usage_dir.mkdir(parents=True, exist_ok=True)
    return usage_dir


def cache_root() -> Path:
    root = (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
        / "omarchy"
        / "agent-usage"
    )
    root.mkdir(parents=True, exist_ok=True)
    return root


def load_auth_config() -> dict[str, dict]:
    auth_paths = [
        Path.home() / ".pi" / "agent" / "auth.json",
        Path.home() / ".omp" / "agent" / "auth.json",
    ]
    merged_auth: dict[str, dict] = {}
    for p in auth_paths:
        if p.exists():
            try:
                with open(p, encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        for k, v in data.items():
                            if isinstance(v, dict):
                                canonical = PROVIDER_CANONICAL.get(k, k)
                                if canonical not in merged_auth:
                                    merged_auth[canonical] = v
            except COMMON_ERRORS as e:
                print(f"Error reading auth file {p}: {e}", file=sys.stderr)
    return merged_auth


def http_get(url: str, headers: dict, timeout: float = 4.0) -> tuple[int, str]:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.status, resp.read().decode("utf-8", errors="replace")


def empty_result() -> dict:
    return {
        "ready": True,
        "tierLabel": "",
        "balance": None,
        "limits": [],
        "usageStatusText": "",
        "authHelpText": "",
    }


def fail_res(
    res: dict,
    status_text: str,
    help_text: str,
    limits: list | None = None,
) -> dict:
    res["ready"] = False
    res["usageStatusText"] = status_text
    res["authHelpText"] = help_text
    if limits is not None:
        res["limits"] = limits
    return res


# ----------------------------------------------------------- upstream probes


def probe_deepseek(key: str) -> dict:
    res = empty_result()
    res["tierLabel"] = DEFAULT_TIERS["deepseek"]
    if not key:
        return fail_res(res, "API key missing", "Add key to ~/.pi/agent/auth.json")
    try:
        status, body = http_get(
            "https://api.deepseek.com/user/balance",
            {"Authorization": f"Bearer {key}"},
        )
        if status == 200:
            data = json.loads(body)
            infos = data.get("balance_infos", [])
            if not infos or not data.get("is_available", True):
                return fail_res(
                    res,
                    "Balance depleted / inactive",
                    "Top up at platform.deepseek.com",
                )
            info = infos[0]
            currency = str(info.get("currency") or "CNY")
            total_bal = float(info.get("total_balance") or 0.0)
            topped_up = float(info.get("topped_up_balance") or 0.0)
            granted = float(info.get("granted_balance") or 0.0)
            funded = max(total_bal, topped_up + granted)
            res["balance"] = {
                "remaining": total_bal,
                "funded": funded if funded > 0 else total_bal,
                "spent": max(0.0, funded - total_bal),
                "currency": currency,
                "estimated": False,
            }
            symbol = "￥" if currency == "CNY" else "$"
            res["tierLabel"] = f"Balance: {symbol}{total_bal:.2f}"
            res["ready"] = True
        elif status in (401, 403):
            return fail_res(
                res, "API key invalid", "Check key in ~/.pi/agent/auth.json"
            )
        elif status == 402:
            return fail_res(res, "Payment required", "Top up at platform.deepseek.com")
        else:
            return fail_res(res, f"Upstream error ({status})", "")
    except urllib.error.HTTPError as e:
        return fail_res(res, f"Upstream error ({e.code})", "")
    except COMMON_ERRORS as e:
        print(f"DeepSeek probe error: {e}", file=sys.stderr)
    return res


def probe_opencode(token: str) -> dict:
    res = empty_result()
    res["tierLabel"] = DEFAULT_TIERS["opencode"]
    if not token:
        return fail_res(res, "Token missing", "Configure key in Pi")
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": (
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
            " (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"
        ),
    }
    try:
        status, body = http_get("https://opencode.ai/zen/go/v1/usage", headers)
        if status != 200:
            return fail_res(res, f"OpenCode error ({status})", "Check key in Pi")
        data = json.loads(body).get("usage", {})
        for window_name in ("rolling", "weekly", "monthly"):
            win = data.get(window_name, {}) or {}
            pct = float(win.get("percent", 0))
            resets = win.get("resetsAt", "")
            title = window_name.capitalize()
            res["limits"].append(
                {
                    "title": title,
                    "percent": min(1.0, pct / 100.0),
                    "resetsAt": resets,
                }
            )
            if win.get("status") == "rate-limited" or pct >= 100:
                res["ready"] = False
                res["usageStatusText"] = f"{title} limit reached"
        if res["ready"]:
            res["tierLabel"] = "OpenCode API (Active)"
    except urllib.error.HTTPError as e:
        return fail_res(res, f"OpenCode error ({e.code})", "Check key in Pi")
    except COMMON_ERRORS as e:
        print(f"OpenCode probe error: {e}", file=sys.stderr)
    return res


def probe_openrouter(token: str) -> dict:
    res = empty_result()
    res["tierLabel"] = DEFAULT_TIERS["openrouter"]
    if not token:
        return fail_res(res, "Token missing", "Configure key in Pi")
    headers = {"Authorization": f"Bearer {token}"}

    try:
        status, body = http_get("https://openrouter.ai/api/v1/credits", headers)
        if status == 200:
            data = json.loads(body).get("data", {})
            total_credits = float(data.get("total_credits") or 0.0)
            total_usage = float(data.get("total_usage") or 0.0)
            if total_credits > 0 or total_usage > 0:
                remaining = max(0.0, total_credits - total_usage)
                res["balance"] = {
                    "remaining": remaining,
                    "funded": total_credits,
                    "spent": total_usage,
                    "currency": "USD",
                    "estimated": False,
                }
                res["tierLabel"] = (
                    f"Credit: ${remaining:.2f}" if total_credits else "Free Tier"
                )
    except COMMON_ERRORS as e:
        print(f"OpenRouter credits probe error: {e}", file=sys.stderr)

    try:
        status, body = http_get("https://openrouter.ai/api/v1/auth/key", headers)
        if status in (401, 403):
            return fail_res(
                res, "API token expired or invalid", "Re-authenticate in Pi"
            )
        if status == 200:
            data = json.loads(body).get("data", {})
            is_free = data.get("is_free_tier", False)
            limit = data.get("limit")
            usage = float(data.get("usage") or 0.0)
            limit_reset = data.get("limit_reset")
            if res["balance"] is None and is_free:
                res["tierLabel"] = "Free Tier"
            elif limit is not None:
                try:
                    limit_val = float(limit)
                except (TypeError, ValueError):
                    limit_val = 0
                if limit_val > 0:
                    res["tierLabel"] = f"Usage: ${usage:.2f} / ${limit_val:.2f}"
                    res["limits"].append(
                        {
                            "title": "Spending Limit",
                            "percent": min(1.0, usage / limit_val),
                            "resetsAt": str(limit_reset or ""),
                        }
                    )
    except COMMON_ERRORS as e:
        print(f"OpenRouter key probe error: {e}", file=sys.stderr)
    return res


def probe_google(key: str, timeout: float = 4.0) -> dict:
    res = empty_result()
    res["tierLabel"] = DEFAULT_TIERS["google"]
    if not key:
        return fail_res(res, "API key missing", "Add key to ~/.pi/agent/auth.json")
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models"
        f"?key={urllib.parse.quote(key)}"
    )
    try:
        status, _ = http_get(url, {}, timeout)
        if status == 200:
            res["ready"] = True
            res["tierLabel"] = "Gemini API (Active)"
        else:
            return fail_res(res, f"Google API error ({status})", "")
    except COMMON_ERRORS as e:
        print(f"Google probe error: {e}", file=sys.stderr)
    return res


def refresh_kimi_oauth(auth_entry: dict) -> str | None:
    refresh_token = auth_entry.get("refresh")
    if not refresh_token:
        return None
    url = "https://auth.kimi.com/api/oauth/token"
    data = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": "17e5f671-d194-4dfb-9706-5516cb48c098",
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
            access_token = payload.get("access_token")
            new_refresh = payload.get("refresh_token")
            expires_in = payload.get("expires_in", 900)
            if access_token:
                auth_entry["access"] = access_token
                if new_refresh:
                    auth_entry["refresh"] = new_refresh
                auth_entry["expires"] = int((time.time() + expires_in) * 1000)
                auth_path = Path.home() / ".pi" / "agent" / "auth.json"
                if auth_path.exists():
                    try:
                        all_auth = json.loads(auth_path.read_text(encoding="utf-8"))
                        canonical_key = (
                            "kimi-coding" if "kimi-coding" in all_auth else "kimi"
                        )
                        all_auth[canonical_key] = auth_entry
                        auth_path.write_text(
                            json.dumps(all_auth, indent=2), encoding="utf-8"
                        )
                    except COMMON_ERRORS:
                        pass
                return access_token
    except COMMON_ERRORS as e:
        print(f"Kimi token refresh failed: {e}", file=sys.stderr)
    return None


def probe_oauth_provider(provider_id: str, auth_entry: dict | None) -> dict:
    res = empty_result()
    res["tierLabel"] = DEFAULT_TIERS.get(provider_id, "API")
    if not auth_entry:
        return fail_res(res, "Not configured", "Authenticate in Pi")

    token = (
        auth_entry.get("access")
        or auth_entry.get("key")
        or auth_entry.get("token")
        or ""
    )
    exp = auth_entry.get("expires")
    now_ms = time.time() * 1000

    if (
        exp
        and isinstance(exp, (int, float))
        and exp < 9e14
        and exp < now_ms
        and provider_id in ("kimi-coding", "kimi")
        and auth_entry.get("refresh")
    ):
        refreshed = refresh_kimi_oauth(auth_entry)
        if refreshed:
            token = refreshed
            exp = auth_entry.get("expires")

    if exp and isinstance(exp, (int, float)) and exp < 9e14:
        if exp < now_ms:
            return fail_res(
                res,
                "OAuth token expired",
                "Re-authenticate in Pi",
            )
        res["ready"] = True

    if provider_id in ("kimi-coding", "kimi") and token:
        try:
            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "anthropic-version": "2023-06-01",
                "anthropic-beta": "prompt-caching-2024-07-31",
            }
            status, _ = http_get(
                "https://api.kimi.com/coding/v1/models", headers=headers
            )
            res["ready"] = status == 200
            if status == 200:
                res["tierLabel"] = "Kimi K3 Coding (Active)"
            else:
                return fail_res(
                    res, "Kimi token unauthorized", "Re-authenticate Kimi in Pi"
                )
        except COMMON_ERRORS:
            pass
    elif provider_id == "xai" and token:
        try:
            status, _ = http_get(
                "https://api.x.ai/v1/models", {"Authorization": f"Bearer {token}"}
            )
            res["ready"] = status == 200
            if status == 200:
                res["tierLabel"] = "Grok API (Active)"
            else:
                return fail_res(res, "xAI token invalid", "Re-authenticate xAI in Pi")
        except COMMON_ERRORS:
            pass
    return res


def probe_upstream(provider_id: str, auth_entry: dict | None) -> dict:
    if not auth_entry:
        return fail_res(empty_result(), "Not configured", "Authenticate in Pi")
    key = (
        auth_entry.get("key")
        or auth_entry.get("access")
        or auth_entry.get("token")
        or ""
    )
    if provider_id == "deepseek":
        return probe_deepseek(key)
    elif provider_id in ("opencode", "opencode-go"):
        return probe_opencode(key)
    elif provider_id == "openrouter":
        return probe_openrouter(key)
    elif provider_id == "google":
        return probe_google(key)
    else:
        return probe_oauth_provider(provider_id, auth_entry)


# ------------------------------------------------------ fast local log scan


def parse_timestamp_to_local_day(ts_str: str, today_str: str) -> str:
    if not ts_str:
        return today_str
    try:
        if ts_str.endswith("Z"):
            dt_val = datetime.fromisoformat(ts_str[:-1] + "+00:00").astimezone()
        else:
            dt_val = datetime.fromisoformat(ts_str)
            if dt_val.tzinfo is not None:
                dt_val = dt_val.astimezone()
        return dt_val.strftime("%Y-%m-%d")
    except COMMON_ERRORS:
        return ts_str[:10] if len(ts_str) >= 10 else today_str


def scan_single_file(sf: Path, today_str: str) -> dict:
    stats: dict[str, dict] = {}
    try:
        with open(sf, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                if '"usage":' not in line or '"role":"assistant"' not in line:
                    continue

                um = USAGE_RE.search(line)
                if not um:
                    continue
                try:
                    usage = json.loads(um.group(1))
                except COMMON_ERRORS:
                    continue

                pm = PROV_RE.search(line)
                raw_provider = pm.group(1) if pm else "unknown"

                if raw_provider == "opencode":
                    continue

                provider = PROVIDER_CANONICAL.get(raw_provider, raw_provider)
                if provider in ("openai-codex", "codex", "claude"):
                    continue

                mm = MODEL_RE.search(line)
                model = mm.group(1) if mm else "unknown"

                tm = TS_RE.search(line)
                ts_str = tm.group(1) if tm else ""
                day = parse_timestamp_to_local_day(ts_str, today_str)

                inp = int(usage.get("input") or 0)
                out = int(usage.get("output") or 0)
                cr = int(usage.get("cacheRead") or 0)
                cw = int(usage.get("cacheWrite") or 0)
                tot = int(usage.get("totalTokens") or (inp + out + cr + cw))
                if tot <= 0:
                    continue

                rec = stats.setdefault(
                    provider,
                    {
                        "prompts_by_day": {},
                        "tokens_by_day": {},
                        "models_by_day": {},
                        "total_prompts": 0,
                        "model_usage": {},
                    },
                )
                rec["total_prompts"] += 1
                rec["prompts_by_day"][day] = rec["prompts_by_day"].get(day, 0) + 1
                rec["tokens_by_day"][day] = rec["tokens_by_day"].get(day, 0) + tot

                day_models = rec["models_by_day"].setdefault(day, {})
                dm = day_models.setdefault(
                    model, {"i": 0, "o": 0, "cr": 0, "cw": 0, "t": 0}
                )
                dm["i"] += inp
                dm["o"] += out
                dm["cr"] += cr
                dm["cw"] += cw
                dm["t"] += tot

                mu = rec["model_usage"].setdefault(
                    model, {"i": 0, "o": 0, "cr": 0, "cw": 0}
                )
                mu["i"] += inp
                mu["o"] += out
                mu["cr"] += cr
                mu["cw"] += cw
    except COMMON_ERRORS as e:
        print(f"Warning reading {sf}: {e}", file=sys.stderr)
    return stats


def scan_pi_sessions_cached(force: bool = False) -> dict[str, dict]:
    today_dt = datetime.now().date()
    today_str = today_dt.strftime("%Y-%m-%d")
    recent_days = [
        (today_dt - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)
    ]

    roots = [
        Path.home() / ".pi" / "agent" / "sessions",
        Path.home() / ".omp" / "agent" / "sessions",
    ]
    session_files = []
    for r in roots:
        if r.exists():
            session_files.extend(r.glob("**/*.jsonl"))

    cache_file = cache_root() / "pi-sessions-cache.json"
    lock_file = cache_root() / "pi-sessions.lock"

    with open(lock_file, "w") as lock_handle:
        fcntl.flock(lock_handle, fcntl.LOCK_EX)

        cached_files: dict = {}
        if not force and cache_file.exists():
            try:
                with open(cache_file, encoding="utf-8") as f:
                    cached = json.load(f)
                if cached.get("version") == CACHE_VERSION:
                    cached_files = cached.get("files", {})
            except COMMON_ERRORS:
                cached_files = {}

        live_paths = set()
        out_files: dict = {}
        scanned = 0
        for sf in session_files:
            key = str(sf)
            live_paths.add(key)
            try:
                st = sf.stat()
            except OSError:
                continue
            entry = cached_files.get(key)
            if (
                entry
                and entry.get("mtime_ns") == st.st_mtime_ns
                and entry.get("size") == st.st_size
            ):
                out_files[key] = entry
                continue
            stats = scan_single_file(sf, today_str)
            scanned += 1
            out_files[key] = {
                "mtime_ns": st.st_mtime_ns,
                "size": st.st_size,
                "stats": stats,
            }

        out_files = {k: v for k, v in out_files.items() if k in live_paths}

        if scanned or len(out_files) != len(cached_files):
            tmp_fd, tmp_path = tempfile.mkstemp(
                dir=str(cache_root()), prefix="pi-sessions-", suffix=".tmp"
            )
            with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
                json.dump({"version": CACHE_VERSION, "files": out_files}, f)
            os.replace(tmp_path, str(cache_file))

    # Merge stats across files
    records = defaultdict(
        lambda: {
            "totalPrompts": 0,
            "totalSessions": set(),
            "todayPrompts": 0,
            "todaySessions": set(),
            "todayTotalTokens": 0,
            "todayTokensByModel": defaultdict(int),
            "recentDays": {d: 0 for d in recent_days},
            "activeDates": set(),
            "modelUsage": defaultdict(
                lambda: {
                    "inputTokens": 0,
                    "outputTokens": 0,
                    "cacheReadInputTokens": 0,
                    "cacheCreationInputTokens": 0,
                }
            ),
        }
    )

    for path, entry in out_files.items():
        for provider, st in (entry.get("stats") or {}).items():
            rec = records[provider]
            total_prompts = st.get("total_prompts", 0)
            if total_prompts <= 0:
                continue
            rec["totalPrompts"] += total_prompts
            rec["totalSessions"].add(path)

            prompts_by_day = st.get("prompts_by_day", {})
            tokens_by_day = st.get("tokens_by_day", {})
            rec["activeDates"].update(prompts_by_day.keys())

            for day, tokens in tokens_by_day.items():
                if day in rec["recentDays"]:
                    rec["recentDays"][day] += tokens

            today_prompts = prompts_by_day.get(today_str, 0)
            if today_prompts > 0:
                rec["todayPrompts"] += today_prompts
                rec["todaySessions"].add(path)
                rec["todayTotalTokens"] += tokens_by_day.get(today_str, 0)
                for model, b in st.get("models_by_day", {}).get(today_str, {}).items():
                    rec["todayTokensByModel"][model] += b.get("t", 0)

            for model, b in st.get("model_usage", {}).items():
                mrec = rec["modelUsage"][model]
                mrec["inputTokens"] += b.get("i", 0)
                mrec["outputTokens"] += b.get("o", 0)
                mrec["cacheReadInputTokens"] += b.get("cr", 0)
                mrec["cacheCreationInputTokens"] += b.get("cw", 0)

    return records


# ---------------------------------------------------------------- main merge


def collect_all_records(force: bool = False) -> dict[str, dict]:
    auth_map = load_auth_config()

    # 1. Fast incremental local log scan (< 0.05s cached)
    local_stats = scan_pi_sessions_cached(force=force)

    provider_ids = set(PROVIDER_CANONICAL.get(k, k) for k in auth_map)
    provider_ids |= set(local_stats.keys())
    provider_ids = {
        p
        for p in provider_ids
        if p in PROVIDER_NAMES and p not in ("openai-codex", "codex", "claude")
    }

    today_dt = datetime.now().date()
    recent_days = [
        (today_dt - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)
    ]
    now_iso = datetime.now().astimezone().isoformat()
    results: dict[str, dict] = {}

    # 2. Parallel upstream probes
    upstreams: dict[str, dict] = {}
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {
            pid: pool.submit(probe_upstream, pid, auth_map.get(pid))
            for pid in provider_ids
        }
        for pid, future in futures.items():
            try:
                upstreams[pid] = future.result()
            except COMMON_ERRORS as e:
                print(f"Upstream probe failed for {pid}: {e}", file=sys.stderr)
                upstreams[pid] = {}

    # 3. Merge local stats & upstream status
    for pid in provider_ids:
        up = upstreams.get(pid) or {}
        rec = local_stats.get(pid)

        if rec:
            active_dates_sorted = sorted(list(rec["activeDates"]))
            recent_days_list = [
                {"date": d, "messageCount": rec["recentDays"][d]} for d in recent_days
            ]
            today_prompts = rec["todayPrompts"]
            today_sessions = len(rec["todaySessions"])
            today_tokens = rec["todayTotalTokens"]
            today_by_model = dict(rec["todayTokensByModel"])
            total_prompts = rec["totalPrompts"]
            total_sessions = len(rec["totalSessions"])
            active_days = len(active_dates_sorted)
            model_usage = {m: dict(stats) for m, stats in rec["modelUsage"].items()}
        else:
            active_dates_sorted = []
            recent_days_list = [{"date": d, "messageCount": 0} for d in recent_days]
            today_prompts = 0
            today_sessions = 0
            today_tokens = 0
            today_by_model = {}
            total_prompts = 0
            total_sessions = 0
            active_days = 0
            model_usage = {}

        out = {
            "schemaVersion": 1,
            "id": pid,
            "name": PROVIDER_NAMES.get(pid, pid.replace("-", " ").title()),
            "updatedAt": now_iso,
            "ready": up.get("ready", True),
            "hasLocalStats": True,
            "hasPromptStats": True,
            "todayPrompts": today_prompts,
            "todaySessions": today_sessions,
            "todayTotalTokens": today_tokens,
            "todayTokensByModel": today_by_model,
            "recentDays": recent_days_list,
            "totalPrompts": total_prompts,
            "totalSessions": total_sessions,
            "activeDays": active_days,
            "activeDates": active_dates_sorted,
            "modelUsage": model_usage,
            "limits": up.get("limits", []),
            "tierLabel": up.get("tierLabel", ""),
            "balance": up.get("balance"),
            "usageStatusText": up.get("usageStatusText", ""),
            "authHelpText": up.get("authHelpText", ""),
        }
        results[pid] = out

    return results


def write_records(records: dict[str, dict], usage_dir: Path) -> None:
    for pid, rec in records.items():
        target_path = usage_dir / f"{pid}.json"
        content = json.dumps(rec, indent=2, ensure_ascii=False) + "\n"
        tmp_fd, tmp_path = tempfile.mkstemp(
            dir=str(usage_dir), prefix=f".{pid}.", suffix=".tmp"
        )
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp_path, str(target_path))


def main() -> None:
    parser = argparse.ArgumentParser(description="Collect Pi provider usage records")
    parser.add_argument("--force", action="store_true", help="Force refresh")
    parser.add_argument(
        "--limits-only", action="store_true", help="Limits only refresh"
    )
    args = parser.parse_args()

    usage_dir = get_usage_dir()
    records = collect_all_records(force=args.force)
    write_records(records, usage_dir)
    print(
        f"Updated {len(records)} Pi provider records (fast scan + upstream"
        f" quota) in {usage_dir}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
