#!/bin/sh
# Global terminal configuration
# Source this file in scripts to get the configured terminal

# Terminal emulator
export TERMINAL="alacritty"

# Terminal command for launching
export TERM_CMD="alacritty"

# Terminal command with custom app-id (for window-specific rules)
# Usage: $TERM_APP_ID myapp -- mycommand
export TERM_APP_ID="alacritty --class"
