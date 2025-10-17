#!/bin/sh
# One Light color theme
# Based on Atom's One Light color scheme
# Usage: source this file in shell scripts to access color variables

# Background colors (light)
export COLOR_BG0="#fafafa"          # Main background
export COLOR_BG1="#f0f0f0"          # Slightly darker background
export COLOR_BG2="#e5e5e5"          # Darker background (selection, gutter)
export COLOR_BG3="#d0d0d0"          # Even darker (borders, dividers)

# Foreground colors (dark)
export COLOR_FG0="#383a42"          # Main foreground
export COLOR_FG1="#202227"          # Darker foreground
export COLOR_FG2="#a0a1a7"          # Lighter foreground (comments)

# Accent colors (vibrant, adjusted for light background)
export COLOR_RED="#e45649"          # Red (errors, deletion)
export COLOR_GREEN="#50a14f"        # Green (strings, addition)
export COLOR_YELLOW="#c18401"       # Yellow (warnings, classes)
export COLOR_BLUE="#4078f2"         # Blue (functions, keywords)
export COLOR_PURPLE="#a626a4"       # Purple (constants, tags)
export COLOR_CYAN="#0184bc"         # Cyan (support, regex)
export COLOR_ORANGE="#986801"       # Orange (numbers, operators)

# Muted accent colors
export COLOR_RED_DIM="#ca5241"      # Dim red
export COLOR_GREEN_DIM="#42873f"    # Dim green
export COLOR_YELLOW_DIM="#b17401"   # Dim yellow
export COLOR_BLUE_DIM="#3867d6"     # Dim blue
export COLOR_PURPLE_DIM="#8f1f91"   # Dim purple
export COLOR_CYAN_DIM="#01729b"     # Dim cyan
export COLOR_ORANGE_DIM="#825801"   # Dim orange

# Special colors
export COLOR_BLACK="#202227"        # Dark text
export COLOR_WHITE="#ffffff"        # Pure white
export COLOR_TRANSPARENT="#00000000"

# Semantic colors
export COLOR_ERROR="$COLOR_RED"
export COLOR_WARNING="$COLOR_YELLOW"
export COLOR_SUCCESS="$COLOR_GREEN"
export COLOR_INFO="$COLOR_BLUE"

# UI element colors
export COLOR_BORDER_FOCUSED="$COLOR_BLUE"
export COLOR_BORDER_UNFOCUSED="$COLOR_BG3"
export COLOR_SELECTION="$COLOR_BG2"
export COLOR_CURSOR="$COLOR_BLUE"

# Convert hex to riverctl format (0xRRGGBBAA)
# Usage: hex_to_river "#4078f2" -> "0x4078f2ff"
hex_to_river() {
    echo "0x${1#\#}ff"
}

# Predefined riverctl colors
export RIVER_BORDER_FOCUSED="$(hex_to_river $COLOR_BLUE)"
export RIVER_BORDER_UNFOCUSED="$(hex_to_river $COLOR_BG3)"
export RIVER_BACKGROUND="$(hex_to_river $COLOR_BG0)"
