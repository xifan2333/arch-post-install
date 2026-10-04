#!/usr/bin/env -S PYTHONDONTWRITEBYTECODE=1 python3
"""Validate desktop bin metadata, i18n parity, and zero hardcoded user strings."""

import json
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZH_PATH = os.path.join(REPO_ROOT, "dotfiles/.config/i18n/zh-cn.json")
EN_PATH = os.path.join(REPO_ROOT, "dotfiles/.config/i18n/en-us.json")
BIN_DIR = os.path.join(REPO_ROOT, "dotfiles/.local/bin")

failed = False


def error(msg: str) -> None:
    global failed
    failed = True
    sys.stderr.write(f"❌ {msg}\n")


def success(msg: str) -> None:
    sys.stdout.write(f"✔ {msg}\n")


def load_i18n():
    try:
        with open(ZH_PATH, encoding="utf-8") as f:
            zh = json.load(f)
        with open(EN_PATH, encoding="utf-8") as f:
            en = json.load(f)
        return zh, en
    except (OSError, json.JSONDecodeError) as e:
        error(f"Failed to load i18n dictionaries: {e}")
        return {}, {}


def check_i18n_parity(zh: dict, en: dict):
    zh_keys = set(zh.keys())
    en_keys = set(en.keys())

    diff_zh = zh_keys - en_keys
    diff_en = en_keys - zh_keys

    if diff_zh:
        error(f"Keys in zh-cn.json missing in en-us.json: {sorted(diff_zh)}")
    if diff_en:
        error(f"Keys in en-us.json missing in zh-cn.json: {sorted(diff_en)}")

    if not diff_zh and not diff_en and zh_keys:
        success(f"i18n parity verified ({len(zh_keys)} keys matched)")


def check_script(path: str, valid_keys: set):
    rel = os.path.relpath(path, REPO_ROOT)
    filename = os.path.basename(path)
    if os.path.islink(path) or filename.startswith(".") or filename == "wps-office":
        return

    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except OSError as e:
        error(f"{rel}: cannot read file: {e}")
        return

    # 1. Metadata check: arch:summary in first 5 lines
    first_lines = lines[:5]
    has_summary = any("arch:summary=" in line_text for line_text in first_lines)
    if not has_summary:
        error(f"{rel}: missing '# arch:summary=' metadata in top 5 lines")

    content = "".join(lines)

    # 2. Check referenced keys
    ref_keys = re.findall(r"x-i18n\s+get\s+([a-zA-Z0-9_]+)", content)
    ref_keys += re.findall(r'i18n\(\s*["\']([a-zA-Z0-9_]+)["\']', content)
    for k in set(ref_keys):
        if k not in valid_keys:
            error(f"{rel}: references undefined i18n key '{k}'")

    # 3. Check for hardcoded notify-send string literals
    notify_re = re.compile(r'notify-send\s+(?:-[a-z]+\s+\S+\s+)*["\'][^"\'\$]+["\']')
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if (
            notify_re.search(stripped)
            and "x-i18n" not in stripped
            and "$(" not in stripped
        ):
            error(f"{rel}:{idx}: hardcoded notify-send literal bypassing x-i18n")

    # 4. Check for hardcoded dmenu prompt literals
    dmenu_re = re.compile(r'dmenu\s+(?:--lines\s+\S+\s+)*["\'][^"\'\$]+["\']')
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if (
            dmenu_re.search(stripped)
            and "x-i18n" not in stripped
            and "$(" not in stripped
        ):
            error(f"{rel}:{idx}: hardcoded dmenu prompt literal bypassing x-i18n")


def main():
    zh, en = load_i18n()
    all_keys = set(zh.keys())

    args = sys.argv[1:]
    target_files = [os.path.abspath(a) for a in args if os.path.exists(a)]

    if not target_files:
        # Full repository audit
        check_i18n_parity(zh, en)
        scripts = sorted(
            [
                os.path.join(BIN_DIR, f)
                for f in os.listdir(BIN_DIR)
                if not os.path.islink(os.path.join(BIN_DIR, f))
            ]
        )
        for s in scripts:
            check_script(s, all_keys)
    else:
        # Scoped check
        has_i18n_change = any(
            f.endswith("zh-cn.json") or f.endswith("en-us.json") for f in target_files
        )
        if has_i18n_change:
            check_i18n_parity(zh, en)

        for f in target_files:
            if "dotfiles/.local/bin" in f:
                check_script(f, all_keys)

    if not failed:
        success("Standards and i18n validation passed cleanly")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
