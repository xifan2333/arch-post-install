#!/usr/bin/env bash
# TARGET: ~/.config/river/theme.sh
# Update River border colors and theme variables dynamically
set -euo pipefail

export RIVER_BORDER_FOCUSED="0x{{ accent_strip }}"
export RIVER_BORDER_UNFOCUSED="0x{{ muted_strip }}"
export RIVER_BORDER_URGENT="0x{{ red_strip }}"
export RIVER_BACKGROUND="0x{{ background_strip }}"
