#!/usr/bin/env bash
# Explicit one-time migration for #336; never called by runtime commands/bootstrap.
set -euo pipefail
state="${XDG_STATE_HOME:-$HOME/.local/state}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
target="$state/custom-stream-title/history.txt"
sources=()
for source in "$target" "$data/custom-stream-title/history.txt" "$state/wayhud/title_history.txt"; do
    if [[ -e "$source" ]]; then
        [[ -f "$source" && -r "$source" ]] || {
            printf 'Cannot read %s\n' "$source" >&2
            exit 1
        }
        sources+=("$source")
    fi
done
((${#sources[@]})) || exit 0
mkdir -p -- "${target%/*}"
exec {lock}<"${target%/*}"
flock "$lock"
tmp=$(mktemp "${target%/*}/.migration.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
# Canonical history first, then the former data path, then the oldest Wayhud path.
# Preserve all distinct entries during migration, including their order and whitespace.
awk '!seen[$0]++' "${sources[@]}" >"$tmp"
mv -f -- "$tmp" "$target"
for source in "${sources[@]}"; do
    [[ "$source" == "$target" ]] || rm -- "$source"
done
