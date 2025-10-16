#!/bin/sh
# Common wmenu wrapper with theme colors and font
# Usage: source this file and use run_wmenu function

# Load theme colors
load_theme_colors() {
    if [ -f "$HOME/.config/theme/colors.sh" ]; then
        . "$HOME/.config/theme/colors.sh"
    fi

    # Set default colors
    COLOR_BG0="${COLOR_BG0:-#282c34}"
    COLOR_FG0="${COLOR_FG0:-#abb2bf}"
    COLOR_BLUE="${COLOR_BLUE:-#61afef}"
    COLOR_GREEN="${COLOR_GREEN:-#98c379}"
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

    # Default font and size
    local WMENU_FONT="${WMENU_FONT:-Noto Sans CJK SC 13}"

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
