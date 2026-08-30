#!/usr/bin/env python3
"""Collect Pi provider quota/balance records via upstream APIs only.

No local transcript scanning: quota and availability come straight from each
provider's usage API (DeepSeek balance, OpenRouter credits, OpenCode usage).
Providers without a public usage REST API (Google, xAI, Kimi) fall back to a
key/token validity probe so they still show live availability.

Outputs display-ready JSON records to ~/.local/state/omarchy/agents/usage/.
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
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
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
    """GET a URL, return (status, body). Timeout kept short so probes stay fast."""
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
            return fail_res(res, f"Upstream error ({status})")
    except urllib.error.HTTPError as e:
        return fail_res(res, f"Upstream error ({e.code})")
    except COMMON_ERRORS as e:
        print(f"DeepSeek probe error: {e}", file=sys.stderr)
    return res


def probe_openrouter(token: str) -> dict:
    res = empty_result()
    res["tierLabel"] = DEFAULT_TIERS["openrouter"]
    if not token:
        return fail_res(res, "Token missing", "Configure key in Pi")
    headers = {"Authorization": f"Bearer {token}"}

    # Credits — the real-time spend ledger.
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

    # Key auth + optional spending limit.
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
    # Google has no account-wide usage REST API; probe key validity / models.
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models"
        f"?key={urllib.parse.quote(key)}"
    )
    try:
        status, _ = http_get(url, {}, timeout)
        if status == 200:
            res["ready"] = True
            res["tierLabel"] = "Gemini API (Active)"
            res["limits"] = [{"title": "API Key", "percent": 0.0, "resetsAt": ""}]
        else:
            return fail_res(res, f"Google API error ({status})")
    except COMMON_ERRORS as e:
        print(f"Google probe error: {e}", file=sys.stderr)
    return res


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

    if exp and isinstance(exp, (int, float)) and exp < 9e14:
        exp_iso = datetime.fromtimestamp(exp / 1000).astimezone().isoformat()
        if exp < now_ms:
            return fail_res(
                res,
                "OAuth token expired",
                "Re-authenticate or refresh token in Pi",
                [{"title": "Session Token", "percent": 1.0, "resetsAt": exp_iso}],
            )
        res["ready"] = True
        res["limits"] = [
            {"title": "Session Token", "percent": 0.0, "resetsAt": exp_iso}
        ]

    if provider_id == "kimi" and token:
        try:
            status, _ = http_get(
                "https://api.kimi.com/coding/v1/models",
                {"Authorization": f"Bearer {token}"},
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


def probe_opencode(token: str) -> dict:
    res = empty_result()
    res["tierLabel"] = DEFAULT_TIERS["opencode"]
    if not token:
        return fail_res(res, "Token missing", "Configure key in Pi")
    # Requires a browser-like UA to pass Cloudflare; returns rolling/weekly/monthly.
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


def probe_upstream(provider_id: str, auth_entry: dict | None) -> dict:
    if not auth_entry:
        return fail_res(
            empty_result(),
            "Not configured",
            "Authenticate in Pi",
        )
    key = (
        auth_entry.get("key")
        or auth_entry.get("access")
        or auth_entry.get("token")
        or ""
    )

    if provider_id == "deepseek":
        return probe_deepseek(key)
    elif provider_id == "openrouter":
        return probe_openrouter(key)
    elif provider_id == "google":
        return probe_google(key)
    elif provider_id in ("opencode", "opencode-go"):
        return probe_opencode(key)
    else:
        return probe_oauth_provider(provider_id, auth_entry)


def collect_all_records() -> dict[str, dict]:
    auth_map = load_auth_config()
    # Only providers that actually hold credentials, plus their canonical aliases.
    provider_ids = set(PROVIDER_CANONICAL.get(k, k) for k in auth_map)
    # Exclude agents owned by Omarchy's official collectors; only handle the
    # Pi-specific providers that have real upstream quota/balance APIs.
    provider_ids = {
        p
        for p in provider_ids
        if p in PROVIDER_NAMES and p not in ("openai-codex", "codex", "claude")
    }

    now_iso = datetime.now().astimezone().isoformat()
    results: dict[str, dict] = {}

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

    for pid in provider_ids:
        up = upstreams.get(pid) or {}
        out = {
            "schemaVersion": 1,
            "id": pid,
            "name": PROVIDER_NAMES.get(pid, pid.replace("-", " ").title()),
            "updatedAt": now_iso,
            "ready": up.get("ready", True),
            "hasLocalStats": False,
            "hasPromptStats": False,
            # No local transcript stats: rely on upstream balances/limits only.
            "todayPrompts": 0,
            "todaySessions": 0,
            "todayTotalTokens": 0,
            "todayTokensByModel": {},
            "recentDays": [],
            "totalPrompts": 0,
            "totalSessions": 0,
            "activeDays": 0,
            "activeDates": [],
            "modelUsage": {},
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
    parser = argparse.ArgumentParser(description="Collect Pi provider quota records")
    parser.add_argument("--force", action="store_true", help="Force refresh")
    parser.add_argument(
        "--limits-only", action="store_true", help="Limits only refresh"
    )
    args = parser.parse_args()  # noqa: F841
    usage_dir = get_usage_dir()
    records = collect_all_records()
    write_records(records, usage_dir)
    print(
        f"Updated {len(records)} Pi provider records (upstream quota APIs) in"
        f" {usage_dir}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
