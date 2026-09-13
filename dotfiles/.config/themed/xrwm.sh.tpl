#!/usr/bin/env bash
# xrwm border color configuration generated from active theme
set -euo pipefail

if command -v xrwm >/dev/null 2>&1; then
	xrwm border-color-focused "{{ accent }}" 2>/dev/null || true
	xrwm border-color-unfocused "{{ muted }}" 2>/dev/null || true
	xrwm border-color-urgent "{{ red }}" 2>/dev/null || true
fi
