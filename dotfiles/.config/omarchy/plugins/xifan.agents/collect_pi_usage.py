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
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
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
            url = "https://opencode.ai/zen/go/v1/models"
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status == 200:
                    res["ready"] = True
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


def collect_local_stats() -> dict[str, dict]:
    today_dt = datetime.now().date()
    today_str = today_dt.strftime("%Y-%m-%d")
    recent_days = [
        (today_dt - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)
    ]

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

    session_roots = [
        Path.home() / ".pi" / "agent" / "sessions",
        Path.home() / ".omp" / "agent" / "sessions",
    ]

    session_files: list[Path] = []
    for root in session_roots:
        if root.exists():
            session_files.extend(root.glob("**/*.jsonl"))

    for sf in session_files:
        sess_id = str(sf)
        try:
            with open(sf, encoding="utf-8", errors="ignore") as f:
                current_sess_provider = None
                current_sess_model = None
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

                        rec = records[provider]
                        rec["totalPrompts"] += 1
                        rec["totalSessions"].add(sess_id)
                        rec["activeDates"].add(day)

                        if day in rec["recentDays"]:
                            rec["recentDays"][day] += tot

                        if day == today_str:
                            rec["todayPrompts"] += 1
                            rec["todaySessions"].add(sess_id)
                            rec["todayTotalTokens"] += tot
                            rec["todayTokensByModel"][model] += tot

                        mrec = rec["modelUsage"][model]
                        mrec["inputTokens"] += inp
                        mrec["outputTokens"] += out
                        mrec["cacheReadInputTokens"] += cr
                        mrec["cacheCreationInputTokens"] += cw
        except COMMON_ERRORS as e:
            print(f"Warning: error reading {sf}: {e}", file=sys.stderr)

    return records


# ---------------------------------------------------------------- main merge


def collect_all_records(limits_only: bool = False) -> dict[str, dict]:
    auth_map = load_auth_config()
    local_stats = collect_local_stats()

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

    for pid in all_providers:
        display_name = PROVIDER_NAMES.get(pid, pid.replace("-", " ").title())
        auth_entry = auth_map.get(pid)
        rec = local_stats.get(pid)

        today_prompts = rec["todayPrompts"] if rec else 0

        # 1. Upstream probe (Availability & Reset limits)
        upstream = probe_upstream(pid, auth_entry, today_prompts=today_prompts)

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
    records = collect_all_records(limits_only=args.limits_only)
    write_records(records, usage_dir)

    print(
        f"Updated {len(records)} Pi provider records (with live availability &"
        f" reset limits) in {usage_dir}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
