#!/bin/sh
# Common wmenu wrapper with theme colors and font
# Usage: source this file and use run_wmenu function

# Parse color from waybar.css
# Usage: parse_waybar_color <color-name>
# Example: parse_waybar_color "color-bg0" returns "#282828"
parse_waybar_color() {
    local color_name="$1"
    local waybar_css="$HOME/.config/current/waybar.css"

    if [ -f "$waybar_css" ]; then
        grep "@define-color $color_name" "$waybar_css" | \
            sed -n 's/.*@define-color [^ ]* \(#[0-9a-fA-F]*\);.*/\1/p' | \
            head -n1
    fi
}

# Load theme colors and font configuration
load_theme_colors() {
    # Try to load colors from current theme's waybar.css
    if [ -f "$HOME/.config/current/waybar.css" ]; then
        COLOR_BG0=$(parse_waybar_color "color-bg0")
        COLOR_FG0=$(parse_waybar_color "color-fg0")
        COLOR_BLUE=$(parse_waybar_color "color-blue")
        COLOR_GREEN=$(parse_waybar_color "color-green")
    fi

    # Set default colors if parsing failed
    COLOR_BG0="${COLOR_BG0:-#282c34}"
    COLOR_FG0="${COLOR_FG0:-#abb2bf}"
    COLOR_BLUE="${COLOR_BLUE:-#61afef}"
    COLOR_GREEN="${COLOR_GREEN:-#98c379}"

    # Load font configuration
    if [ -f "$HOME/.config/current/wmenu-font" ]; then
        . "$HOME/.config/current/wmenu-font"
    fi

    # Set default font if not configured
    WMENU_FONT="${WMENU_FONT:-Noto Sans CJK SC 13}"
}

# Run wmenu with consistent theme colors and font
# Usage: run_wmenu [additional wmenu options]
# Example: echo "item1\nitem2" | run_wmenu -p "Select:"
run_wmenu() {
    load_theme_colors

    # Strip # from colors (wmenu expects RRGGBB format)
    local BG0="${COLOR_BG0#\#}"
    local FG0="${COLOR_FG0#\#}"
    local BLUE="${COLOR_BLUE#\#}"
    local GREEN="${COLOR_GREEN#\#}"

    wmenu \
        -f "$WMENU_FONT" \
        -N "$BG0" \
        -n "$FG0" \
        -M "$BLUE" \
        -m "$BG0" \
        -S "$GREEN" \
        -s "$BG0" \
        "$@"
}

# Export function for use in scripts
export -f run_wmenu load_theme_colors 2>/dev/null || true
