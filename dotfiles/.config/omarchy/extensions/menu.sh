#!/bin/bash
# Thin user adapter loaded by omarchy-menu after its own functions.
# Keep stock Capture entries; only route Screenrecord and OCR to user tools.

capture_extension_msg() {
  bash -c 'source "$HOME/.local/bin/i18n-core" 2>/dev/null && msg "$1"' \
    capture-extension "$1"
}

show_screenrecord_menu() {
  if command -v capture-menu >/dev/null 2>&1; then
    capture-menu
  else
    notify-send -u critical \
      "$(capture_extension_msg capture_notify_title)" \
      "$(capture_extension_msg capture_notify_menu_unavailable)"
  fi
}

# Preserve Omarchy's Capture menu labels; only the OCR command is user-owned.
show_capture_menu() {
  case $(menu "Capture" "  Screenshot\n  Screenrecord\n󰴑  Text Extraction\n󰃉  Color") in
  *Screenshot*) omarchy-capture-screenshot ;;
  *Screenrecord*) show_screenrecord_menu ;;
  *Text*)
    if command -v capture-text-extraction >/dev/null 2>&1; then
      capture-text-extraction
    else
      omarchy-capture-text-extraction
    fi
    ;;
  *Color*) pkill hyprpicker || hyprpicker -a ;;
  *) back_to show_trigger_menu ;;
  esac
}
