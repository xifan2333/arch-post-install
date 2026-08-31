#!/usr/bin/env python3
"""Omarchy agent usage collector.

Discovers and invokes pi-usage CLI to fetch live quotas & local session stats,
and atomically writes state records to ~/.local/state/omarchy/agents/usage/.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

TIER_LABELS = {
    "antigravity": "Google AI Pro",
    "openai-codex": "ChatGPT Plus",
    "codex": "ChatGPT Plus",
    "deepseek": "DeepSeek API",
    "kimi-coding": "Kimi Code",
    "opencode-go": "OpenCode API",
    "opencode": "OpenCode API",
    "openrouter": "OpenRouter",
    "xai": "Grok API",
}


def find_pi_usage_command() -> list[str] | None:
    # 1. Explicit environment variable override
    if custom := os.environ.get("PI_USAGE_BIN"):
        return [custom]

    # 2. Global binary in system PATH (e.g. npm install -g pi-usage)
    if bin_path := shutil.which("pi-usage"):
        return [bin_path]

    # 3. Pi package installation paths & local dev fallbacks
    pi_agent_dir = Path.home() / ".pi" / "agent"
    candidate_paths = [
        pi_agent_dir / "npm" / "node_modules" / "pi-usage" / "dist" / "cli.js",
        (
            pi_agent_dir
            / "npm"
            / "node_modules"
            / "@xifan2284"
            / "pi-usage"
            / "dist"
            / "cli.js"
        ),
        Path.home() / "Code" / "pi-usage" / "dist" / "cli.js",
    ]

    for cand in candidate_paths:
        if cand.exists():
            return ["node", str(cand)]

    # 4. Search git/symlink installations in Pi directory
    for cand in pi_agent_dir.glob("**/pi-usage/dist/cli.js"):
        if cand.exists():
            return ["node", str(cand)]

    return None


def get_usage_dir() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local" / "state")
    usage_dir = Path(state_home) / "omarchy" / "agents" / "usage"
    usage_dir.mkdir(parents=True, exist_ok=True)
    return usage_dir


def to_omarchy_agent_id(provider: str) -> str:
    if provider == "openai-codex":
        return "codex"
    if provider == "opencode-go":
        return "opencode"
    return provider


def convert_snapshot_to_record(snap: dict) -> dict:
    provider = snap.get("provider", "")
    agent_id = to_omarchy_agent_id(provider)
    name = snap.get("name", provider.title())
    now_iso = datetime.now().astimezone().isoformat()
    stats = snap.get("stats") or {}

    limits = []
    balance = None

    for win in snap.get("windows", []):
        raw_label = str(win.get("label") or "Limit")
        if win.get("isCurrency"):
            used = float(win.get("usedValue") or 0.0)
            limit_val = float(win.get("limitValue") or 0.0)
            currency = "CNY" if "CNY" in raw_label else "USD"
            balance = {
                "currency": currency,
                "funded": limit_val if limit_val > 0 else used,
                "remaining": max(0.0, limit_val - used) if limit_val > 0 else used,
                "spent": used if limit_val > 0 else 0.0,
                "estimated": False,
            }
            continue

        pct = float(win.get("usedPercent") or 0.0) / 100.0
        limits.append(
            {
                "title": raw_label,
                "percent": min(1.0, max(0.0, round(pct, 3))),
                "resetsAt": win.get("resetsAt"),
            }
        )

    tier = TIER_LABELS.get(provider, "Active")
    if not snap.get("ok"):
        tier = "Unavailable"

    return {
        "schemaVersion": 1,
        "id": agent_id,
        "name": name,
        "updatedAt": now_iso,
        "ready": snap.get("ok", True),
        "tierLabel": tier,
        "limits": limits,
        "balance": balance,
        "usageStatusText": "",
        "authHelpText": snap.get("error", "") if not snap.get("ok") else "",
        "hasLocalStats": stats.get("hasLocalStats", True),
        "hasPromptStats": stats.get("hasPromptStats", True),
        "todayPrompts": stats.get("todayPrompts", 0),
        "todaySessions": stats.get("todaySessions", 0),
        "todayTotalTokens": stats.get("todayTotalTokens", 0),
        "todayTokensByModel": stats.get("todayTokensByModel", {}),
        "recentDays": stats.get("recentDays", []),
        "totalPrompts": stats.get("totalPrompts", 0),
        "totalSessions": stats.get("totalSessions", 0),
        "activeDays": stats.get("activeDays", 0),
        "activeDates": stats.get("activeDates", []),
        "modelUsage": stats.get("modelUsage", {}),
    }


def write_record_atomically(usage_dir: Path, agent_id: str, record: dict) -> None:
    target = usage_dir / f"{agent_id}.json"
    content = json.dumps(record, indent=2, ensure_ascii=False) + "\n"
    tmp_fd, tmp_path = tempfile.mkstemp(
        dir=str(usage_dir), prefix=f".{agent_id}.", suffix=".tmp"
    )
    with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp_path, str(target))


def main() -> int:
    cmd = find_pi_usage_command()
    if not cmd:
        print("pi-usage executable not found in PATH or ~/.pi/agent", file=sys.stderr)
        return 1

    args = [*cmd, "--json"]
    if "--force" in sys.argv:
        args.append("--force")

    try:
        proc = subprocess.run(args, capture_output=True, text=True, check=False)
        if proc.returncode != 0:
            print(f"pi-usage CLI error: {proc.stderr}", file=sys.stderr)
            return proc.returncode

        snapshots = json.loads(proc.stdout)
        usage_dir = get_usage_dir()

        for snap in snapshots:
            agent_id = to_omarchy_agent_id(snap.get("provider", ""))
            record = convert_snapshot_to_record(snap)
            write_record_atomically(usage_dir, agent_id, record)

        return 0
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as e:
        print(f"Failed to execute pi-usage collector: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
