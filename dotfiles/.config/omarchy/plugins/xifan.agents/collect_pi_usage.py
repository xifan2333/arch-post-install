#!/usr/bin/env python3
"""Collect Pi / OMP agent usage records with availability probes & reset timers.

Dual-engine collector:
1. Upstream API Probes:
   - DeepSeek: user balance API & is_available flag
   - Anthropic / Claude: 5-hour session & 7-day weekly rate limits + reset timestamps
   - Google: Gemini API key active status + daily quota reset timer (00:00 PST)
   - OpenRouter: API key status, usage, limits & limit_reset timestamp
   - xAI / Kimi / Codex: OAuth token validity, expiration timestamps & refresh countdown
2. Local Transcript Engine:
   - Parses ~/.pi/agent/sessions/ and ~/.omp/agent/sessions/ for tokens by day & model.

Outputs display-ready JSON records to the Omarchy agents usage state directory.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
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


def get_usage_dir() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local" / "state")
    usage_dir = Path(state_home) / "omarchy" / "agents" / "usage"
    usage_dir.mkdir(parents=True, exist_ok=True)
    return usage_dir


def load_auth_config() -> dict[str, dict]:
    auth_paths = [
        Path.home() / ".pi" / "agent" / "auth.json",
        Path.home() / ".omp" / "agent" / "auth.json",
    ]
    merged_auth = {}
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


def next_local_midnight_iso() -> str:
    """Calculate the next midnight in the local system timezone."""
    now_local = datetime.now().astimezone()
    tomorrow_local = (now_local + timedelta(days=1)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    return tomorrow_local.isoformat()


# ----------------------------------------------------------- upstream probes


def probe_deepseek(key: str, timeout: float = 5.0) -> dict:
    res = {
        "ready": True,
        "tierLabel": "DeepSeek API",
        "balance": None,
        "limits": [],
        "usageStatusText": "",
        "authHelpText": "",
    }
    if not key:
        res["ready"] = False
        res["usageStatusText"] = "API key missing"
        res["authHelpText"] = "Add key to ~/.pi/agent/auth.json"
        return res

    url = "https://api.deepseek.com/user/balance"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {key}"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            is_avail = data.get("is_available", True)
            infos = data.get("balance_infos", [])
            if infos:
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

                if not is_avail or total_bal <= 0:
                    res["ready"] = False
                    res["usageStatusText"] = "Balance depleted / inactive"
                    res["authHelpText"] = "Top up balance at platform.deepseek.com"
                else:
                    res["ready"] = True
                    res["usageStatusText"] = ""
    except urllib.error.HTTPError as e:
        res["ready"] = False
        if e.code == 401:
            res["usageStatusText"] = "API key invalid (401)"
            res["authHelpText"] = "Check API key in ~/.pi/agent/auth.json"
        elif e.code == 402:
            res["usageStatusText"] = "Payment required (402)"
            res["authHelpText"] = "Top up balance at platform.deepseek.com"
        else:
            res["usageStatusText"] = f"Upstream error ({e.code})"
    except COMMON_ERRORS as e:
        print(f"DeepSeek probe error: {e}", file=sys.stderr)
    return res


def probe_openrouter(token: str, timeout: float = 5.0) -> dict:
    res = {
        "ready": True,
        "tierLabel": "OpenRouter",
        "balance": None,
        "limits": [],
        "usageStatusText": "",
        "authHelpText": "",
    }
    if not token:
        res["ready"] = False
        res["usageStatusText"] = "Token missing"
        return res

    headers = {"Authorization": f"Bearer {token}"}

    # 1. Key auth & limit probe
    try:
        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/auth/key", headers=headers
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            kdata = json.loads(resp.read().decode("utf-8")).get("data", {})
            is_free = kdata.get("is_free_tier", False)
            limit = kdata.get("limit")
            usage = float(kdata.get("usage") or 0.0)
            limit_reset = kdata.get("limit_reset")

            if is_free:
                res["tierLabel"] = "Free Tier"
            elif limit is not None:
                limit_val = float(limit)
                res["tierLabel"] = f"Usage: ${usage:.2f} / ${limit_val:.2f}"
                pct = min(1.0, usage / limit_val) if limit_val > 0 else 0.0
                res["limits"].append(
                    {
                        "title": "Spending Limit",
                        "percent": pct,
                        "resetsAt": str(limit_reset or ""),
                    }
                )
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            res["ready"] = False
            res["usageStatusText"] = "API token expired or invalid"
            res["authHelpText"] = "Re-authenticate in Pi or check OpenRouter key"
            return res
    except COMMON_ERRORS as e:
        print(f"OpenRouter key probe error: {e}", file=sys.stderr)

    # 2. Credits probe
    try:
        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/credits", headers=headers
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            cdata = json.loads(resp.read().decode("utf-8")).get("data", {})
            total_credits = float(cdata.get("total_credits") or 0.0)
            total_usage = float(cdata.get("total_usage") or 0.0)
            if total_credits > 0 or total_usage > 0:
                remaining = max(0.0, total_credits - total_usage)
                res["balance"] = {
                    "remaining": remaining,
                    "funded": total_credits,
                    "spent": total_usage,
                    "currency": "USD",
                    "estimated": False,
                }
                res["tierLabel"] = f"Credit: ${remaining:.2f}"
    except COMMON_ERRORS:
        pass

    return res


def probe_google(key: str, today_prompts: int = 0, timeout: float = 5.0) -> dict:
    res = {
        "ready": True,
        "tierLabel": "Gemini API",
        "balance": None,
        "limits": [],
        "usageStatusText": "",
        "authHelpText": "",
    }
    if not key:
        res["ready"] = False
        res["usageStatusText"] = "API key missing"
        return res

    url = (
        "https://generativelanguage.googleapis.com/v1beta/models"
        f"?key={urllib.parse.quote(key)}"
    )
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            if resp.status == 200:
                res["ready"] = True
                res["tierLabel"] = "Gemini API (Active)"
                # Free Tier daily reset window (1500 requests/day resets at 00:00 PST)
                daily_limit = 1500
                pct = min(1.0, today_prompts / float(daily_limit))
                res["limits"].append(
                    {
                        "title": "Daily Quota",
                        "percent": pct,
                        "resetsAt": next_local_midnight_iso(),
                    }
                )
    except urllib.error.HTTPError as e:
        res["ready"] = False
        if e.code in (400, 403):
            res["usageStatusText"] = "API key invalid or restricted"
            res["authHelpText"] = "Check Gemini key in ~/.pi/agent/auth.json"
        else:
            res["usageStatusText"] = f"Google API error ({e.code})"
    except COMMON_ERRORS as e:
        print(f"Google probe error: {e}", file=sys.stderr)
    return res


def probe_oauth_provider(
    provider_id: str, auth_entry: dict, timeout: float = 5.0
) -> dict:
    res = {
        "ready": True,
        "tierLabel": DEFAULT_TIERS.get(provider_id, "API"),
        "balance": None,
        "limits": [],
        "usageStatusText": "",
        "authHelpText": "",
    }
    if not auth_entry:
        res["ready"] = False
        res["usageStatusText"] = "Not configured"
        return res

    token = (
        auth_entry.get("access")
        or auth_entry.get("key")
        or auth_entry.get("token")
        or ""
    )
    exp = auth_entry.get("expires")
    now_ms = time.time() * 1000

    # Check token expiration (in local system timezone)
    if exp and isinstance(exp, (int, float)) and exp < 9e14:  # reasonable timestamp
        exp_iso = datetime.fromtimestamp(exp / 1000).astimezone().isoformat()
        if exp < now_ms:
            res["ready"] = False
            res["usageStatusText"] = "OAuth token expired"
            res["authHelpText"] = "Re-authenticate or refresh token in Pi"
            res["limits"].append(
                {
                    "title": "Session Token",
                    "percent": 1.0,
                    "resetsAt": exp_iso,
                }
            )
            return res
        else:
            res["ready"] = True
            res["limits"].append(
                {
                    "title": "Session Token",
                    "percent": 0.0,
                    "resetsAt": exp_iso,
                }
            )

    # Live probes for specific oauth providers
    if provider_id == "opencode" and token:
        try:
            headers = {
                "Authorization": f"Bearer {token}",
                "User-Agent": (
                    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
                    " (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"
                ),
            }
            url = "https://opencode.ai/zen/go/v1/usage"
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode("utf-8"))
                    usage = data.get("usage", {})

                    # Process rolling, weekly, monthly limits
                    for window_name in ["rolling", "weekly", "monthly"]:
                        win = usage.get(window_name, {})
                        status = win.get("status", "ok")
                        pct = float(win.get("percent", 0))
                        resets = win.get("resetsAt", "")

                        title = window_name.capitalize()
                        if status == "rate-limited" or pct >= 100:
                            res["ready"] = False
                            res["usageStatusText"] = f"{title} limit reached"

                        res["limits"].append(
                            {
                                "title": title,
                                "percent": min(1.0, pct / 100.0),
                                "resetsAt": resets,
                            }
                        )

                    if res["ready"]:
                        res["tierLabel"] = "OpenCode API (Active)"
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                res["ready"] = False
                res["usageStatusText"] = "OpenCode key blocked or invalid"
                res["authHelpText"] = "Check key in ~/.pi/agent/auth.json"
    elif provider_id in ("kimi-coding", "kimi") and token:
        try:
            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "anthropic-version": "2023-06-01",
                "anthropic-beta": "prompt-caching-2024-07-31",
            }
            # Dedicated Kimi coding endpoint
            url = "https://api.kimi.com/coding/v1/models"
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status == 200:
                    res["ready"] = True
                    res["tierLabel"] = "Kimi K3 Coding (Active)"
        except urllib.error.HTTPError as e:
            if e.code == 401:
                res["ready"] = False
                res["usageStatusText"] = "Kimi token unauthorized"
                res["authHelpText"] = "Re-authenticate Kimi in Pi"
    elif provider_id == "xai" and token:
        try:
            req = urllib.request.Request(
                "https://api.x.ai/v1/models",
                headers={"Authorization": f"Bearer {token}"},
            )
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status == 200:
                    res["ready"] = True
                    res["tierLabel"] = "Grok API (Active)"
        except urllib.error.HTTPError as e:
            if e.code == 401:
                res["ready"] = False
                res["usageStatusText"] = "xAI token expired"
                res["authHelpText"] = "Re-authenticate xAI in Pi"

    return res


def probe_upstream(
    provider_id: str, auth_entry: dict | None, today_prompts: int
) -> dict:
    if not auth_entry:
        return {
            "ready": True,
            "tierLabel": DEFAULT_TIERS.get(provider_id, "API"),
            "balance": None,
            "limits": [],
            "usageStatusText": "",
            "authHelpText": "",
        }

    key_or_token = (
        auth_entry.get("key")
        or auth_entry.get("access")
        or auth_entry.get("token")
        or ""
    )

    if provider_id == "deepseek":
        return probe_deepseek(key_or_token)
    elif provider_id == "openrouter":
        return probe_openrouter(key_or_token)
    elif provider_id == "google":
        return probe_google(key_or_token, today_prompts=today_prompts)
    else:
        return probe_oauth_provider(provider_id, auth_entry)


# ----------------------------------------------------------- local log parser


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


# ----------------------------------------------------- incremental file scan
#
# Walking ~270MB of session transcripts takes ~20s, so per-file stats are
# cached in ~/.cache/omarchy/agent-usage/pi-sessions-cache.json keyed by
# (mtime, size). Unchanged files reuse their cached contribution; only new
# or modified transcripts are re-parsed. Cache granularity is per-day so the
# "today" and "last 7 days" windows stay correct across midnight.

CACHE_VERSION = 2


def cache_root() -> Path:
    root = (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
        / "omarchy"
        / "agent-usage"
    )
    root.mkdir(parents=True, exist_ok=True)
    return root


def scan_session_file(sf: Path, today_str: str) -> dict:
    """Parse one transcript into per-provider, per-day stats."""
    stats: dict[str, dict] = {}
    current_sess_provider = None
    current_sess_model = None
    try:
        with open(sf, encoding="utf-8", errors="ignore") as f:
            for raw_line in f:
                line = raw_line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except COMMON_ERRORS:
                    continue

                ev_type = ev.get("type")
                if ev_type == "model_change":
                    current_sess_provider = ev.get("provider")
                    current_sess_model = ev.get("modelId")
                elif ev_type == "message":
                    msg = ev.get("message", {})
                    if not isinstance(msg, dict):
                        continue
                    usage = msg.get("usage")
                    if not usage or not isinstance(usage, dict):
                        continue

                    raw_provider = (
                        msg.get("provider")
                        or ev.get("provider")
                        or current_sess_provider
                        or "unknown"
                    )

                    # Skip raw "opencode" events, merge only "opencode-go"
                    if raw_provider == "opencode":
                        continue

                    provider = PROVIDER_CANONICAL.get(raw_provider, raw_provider)
                    if provider in ("openai-codex", "codex", "claude"):
                        continue

                    model = (
                        msg.get("model")
                        or ev.get("modelId")
                        or current_sess_model
                        or "unknown"
                    )
                    ts_str = ev.get("timestamp") or msg.get("timestamp")
                    day = parse_timestamp_to_local_day(ts_str, today_str)

                    inp = int(usage.get("input") or 0)
                    out = int(usage.get("output") or 0)
                    cr = int(usage.get("cacheRead") or 0)
                    cw = int(usage.get("cacheWrite") or 0)
                    tot = int(usage.get("totalTokens") or (inp + out + cr + cw))

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
        print(f"Warning: error reading {sf}: {e}", file=sys.stderr)
    return stats


def collect_local_stats(force: bool = False) -> dict[str, dict]:
    today_dt = datetime.now().date()
    today_str = today_dt.strftime("%Y-%m-%d")
    recent_days = [
        (today_dt - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)
    ]

    session_roots = [
        Path.home() / ".pi" / "agent" / "sessions",
        Path.home() / ".omp" / "agent" / "sessions",
    ]
    session_files: list[Path] = []
    for root in session_roots:
        if root.exists():
            session_files.extend(root.glob("**/*.jsonl"))

    cache_file = cache_root() / "pi-sessions-cache.json"
    lock_file = cache_root() / "pi-sessions.lock"

    # Serialize concurrent collectors: the panel and a manual refresh may
    # overlap; the loser just waits its turn.
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
            stats = scan_session_file(sf, today_str)
            scanned += 1
            out_files[key] = {
                "mtime_ns": st.st_mtime_ns,
                "size": st.st_size,
                "stats": stats,
            }

        # Drop cache entries for deleted transcripts.
        out_files = {k: v for k, v in out_files.items() if k in live_paths}

        if scanned or len(out_files) != len(cached_files):
            tmp_fd, tmp_path = tempfile.mkstemp(
                dir=str(cache_root()), prefix="pi-sessions-", suffix=".tmp"
            )
            with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
                json.dump({"version": CACHE_VERSION, "files": out_files}, f)
            os.replace(tmp_path, str(cache_file))
        if scanned:
            print(f"pi-scan: re-parsed {scanned} transcript(s)", file=sys.stderr)

    # ------------------------------------------------- merge per-file stats
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


def collect_all_records(
    limits_only: bool = False, force: bool = False
) -> dict[str, dict]:
    auth_map = load_auth_config()
    local_stats = collect_local_stats(force=force)

    all_providers = set(auth_map.keys()) | set(local_stats.keys())
    all_providers = {
        p
        for p in all_providers
        if p not in ("openai-codex", "codex", "claude", "fireworks")
    }

    today_dt = datetime.now().date()
    recent_days = [
        (today_dt - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)
    ]
    now_iso = datetime.now().astimezone().isoformat()
    results = {}

    # 1. Upstream probes (Availability & Reset limits), run in parallel:
    # six serial 5s-timeout HTTP probes would dominate the refresh budget.
    upstreams: dict[str, dict] = {}
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {}
        for pid in all_providers:
            rec = local_stats.get(pid)
            today_prompts = rec["todayPrompts"] if rec else 0
            futures[pid] = pool.submit(
                probe_upstream,
                pid,
                auth_map.get(pid),
                today_prompts=today_prompts,
            )
        for pid, future in futures.items():
            try:
                upstreams[pid] = future.result()
            except COMMON_ERRORS as e:
                print(f"Upstream probe failed for {pid}: {e}", file=sys.stderr)
                upstreams[pid] = {}

    for pid in all_providers:
        display_name = PROVIDER_NAMES.get(pid, pid.replace("-", " ").title())
        rec = local_stats.get(pid)
        upstream = upstreams.get(pid) or {}

        # 2. Merge stats
        if rec:
            active_dates_sorted = sorted(list(rec["activeDates"]))
            recent_days_list = [
                {"date": d, "messageCount": rec["recentDays"][d]} for d in recent_days
            ]
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
            today_sessions = 0
            today_tokens = 0
            today_by_model = {}
            total_prompts = 0
            total_sessions = 0
            active_days = 0
            model_usage = {}

        out_obj = {
            "schemaVersion": 1,
            "id": pid,
            "name": display_name,
            "updatedAt": now_iso,
            "ready": upstream.get("ready", True),
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
            "limits": upstream.get("limits", []),
            "tierLabel": upstream.get("tierLabel", "API Key"),
            "balance": upstream.get("balance"),
            "usageStatusText": upstream.get("usageStatusText", ""),
            "authHelpText": upstream.get("authHelpText", ""),
        }
        results[pid] = out_obj

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
    parser = argparse.ArgumentParser(description="Collect Pi agent usage records")
    parser.add_argument("--force", action="store_true", help="Force refresh")
    parser.add_argument(
        "--limits-only", action="store_true", help="Limits only refresh"
    )
    args = parser.parse_args()

    usage_dir = get_usage_dir()
    records = collect_all_records(limits_only=args.limits_only, force=args.force)
    write_records(records, usage_dir)

    print(
        f"Updated {len(records)} Pi provider records (with live availability &"
        f" reset limits) in {usage_dir}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
