#!/usr/bin/env python3
"""Omarchy agent usage collector delegate.

Delegates quota collection to pi-usage (TypeScript core).
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

CLI_PATH = Path.home() / "Code" / "pi-usage" / "dist" / "cli.js"


def main() -> int:
    if not CLI_PATH.exists():
        print(f"pi-usage CLI not found at {CLI_PATH}", file=sys.stderr)
        return 1

    args = ["node", str(CLI_PATH), "--quiet"]
    if "--force" in sys.argv:
        args.append("--force")

    try:
        res = subprocess.run(args, check=False)
        return res.returncode
    except (OSError, subprocess.SubprocessError) as e:
        print(f"Failed to execute pi-usage CLI: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
