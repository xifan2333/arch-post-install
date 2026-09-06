#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-gh-alerts"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
ETAG_FILE="$CACHE_DIR/etag.txt"
CACHE_FILE="$CACHE_DIR/filtered.json"
STATE_FILE="$STATE_DIR/gh-alerts.json"

mkdir -p "$CACHE_DIR" "$STATE_DIR"

atomic_write() {
    local src="$1"
    local dst="$2"
    local tmp
    tmp="$(mktemp "${dst}.tmp.XXXXXX")"
    cp -f "$src" "$tmp"
    mv -f "$tmp" "$dst"
}

action="${1:-check}"

if [[ "$action" == "mark-read" || "$action" == "--mark-read" ]]; then
    token="$(gh auth token 2>/dev/null || true)"
    if [[ -n "$token" ]]; then
        curl -s -X PUT \
            -H "Authorization: Bearer $token" \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com/notifications" >/dev/null 2>&1 || true
    fi
    rm -f "$ETAG_FILE"
    now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    empty_payload="{\"count\":0,\"updated_at\":\"$now_iso\",\"items\":[]}"
    echo "$empty_payload" >"$CACHE_FILE"
    atomic_write "$CACHE_FILE" "$STATE_FILE"
    echo "$empty_payload"
    exit 0
fi

token="$(gh auth token 2>/dev/null || true)"
if [[ -z "$token" ]]; then
    if [[ -f "$CACHE_FILE" ]]; then
        cat "$CACHE_FILE"
    else
        echo '{"count":0,"error":"gh auth token not found","items":[]}'
    fi
    exit 0
fi

raw_tmp="$(mktemp "$CACHE_DIR/raw.XXXXXX.json")"
trap 'rm -f "$raw_tmp"' EXIT

curl_args=(
    -s
    -w "%{http_code}"
    -H "Authorization: Bearer $token"
    -H "Accept: application/vnd.github+json"
    --etag-save "$ETAG_FILE"
    -o "$raw_tmp"
)

if [[ -f "$ETAG_FILE" ]]; then
    curl_args+=(--etag-compare "$ETAG_FILE")
fi

http_code="$(curl "${curl_args[@]}" "https://api.github.com/notifications" 2>/dev/null || echo "000")"

if [[ "$http_code" == "304" ]]; then
    if [[ -f "$CACHE_FILE" ]]; then
        atomic_write "$CACHE_FILE" "$STATE_FILE"
        cat "$CACHE_FILE"
        exit 0
    fi
fi

if [[ "$http_code" == "200" && -s "$raw_tmp" ]]; then
    filtered_tmp="$(mktemp "$CACHE_DIR/filtered.XXXXXX.json")"
    jq '
      def to_html_url:
        if .subject.url then
          .subject.url
          | sub("^https://api.github.com/repos/"; "https://github.com/")
          | sub("/pulls/"; "/pull/")
        else
          .repository.html_url
        end;

      [ .[] | select(.reason == "author" and .subject.latest_comment_url == .subject.url | not) | {
        id: .id,
        repo: .repository.full_name,
        type: .subject.type,
        title: .subject.title,
        reason: .reason,
        url: to_html_url,
        updated_at: .updated_at
      } ] | {
        count: length,
        updated_at: (now | todate),
        items: .
      }
    ' "$raw_tmp" >"$filtered_tmp"

    mv -f "$filtered_tmp" "$CACHE_FILE"
    atomic_write "$CACHE_FILE" "$STATE_FILE"
    cat "$CACHE_FILE"
    exit 0
fi

# Fallback on network/auth failure
if [[ -f "$CACHE_FILE" ]]; then
    cat "$CACHE_FILE"
else
    echo '{"count":0,"error":"failed to fetch notifications","items":[]}'
fi
