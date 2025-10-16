#!/bin/sh
# One Dark color theme
# Based on Atom's One Dark color scheme
# Usage: source this file in shell scripts to access color variables

# Background colors
export COLOR_BG0="#282c34"          # Main background
export COLOR_BG1="#2c313a"          # Slightly lighter background
export COLOR_BG2="#3e4451"          # Lighter background (selection, gutter)
export COLOR_BG3="#4b5263"          # Even lighter (borders, dividers)

# Foreground colors
export COLOR_FG0="#abb2bf"          # Main foreground
export COLOR_FG1="#c8ccd4"          # Brighter foreground
export COLOR_FG2="#5c6370"          # Dimmed foreground (comments)

# Accent colors (vibrant)
export COLOR_RED="#e06c75"          # Red (errors, deletion)
export COLOR_GREEN="#98c379"        # Green (strings, addition)
export COLOR_YELLOW="#e5c07b"       # Yellow (warnings, classes)
export COLOR_BLUE="#61afef"         # Blue (functions, keywords)
export COLOR_PURPLE="#c678dd"       # Purple (constants, tags)
export COLOR_CYAN="#56b6c2"         # Cyan (support, regex)
export COLOR_ORANGE="#d19a66"       # Orange (numbers, operators)

# Muted accent colors
export COLOR_RED_DIM="#be5046"      # Dim red
export COLOR_GREEN_DIM="#7a9f60"    # Dim green
export COLOR_YELLOW_DIM="#d19a66"   # Dim yellow
export COLOR_BLUE_DIM="#528bff"     # Dim blue
export COLOR_PURPLE_DIM="#a358b0"   # Dim purple
export COLOR_CYAN_DIM="#3f8f98"     # Dim cyan
export COLOR_ORANGE_DIM="#ca9460"   # Dim orange

# Special colors
export COLOR_BLACK="#21252b"        # Darker than BG0
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
# Usage: hex_to_river "#61afef" -> "0x61afefff"
hex_to_river() {
    echo "0x${1#\#}ff"
}

# Predefined riverctl colors
export RIVER_BORDER_FOCUSED="$(hex_to_river $COLOR_BLUE)"
export RIVER_BORDER_UNFOCUSED="$(hex_to_river $COLOR_BG3)"
export RIVER_BACKGROUND="$(hex_to_river $COLOR_BG0)"
