#!/bin/bash
# User extensions for omarchy-menu (sourced after upstream function definitions).
#
# Extends Trigger → Capture with an "Overlays" entry that opens our
# screenrecord overlay suite (camera/captions/keys/title/audio mix).
#
# NOTE: this overrides show_capture_menu() from omarchy-menu. When Omarchy
# adds new capture entries upstream, mirror them here.

show_capture_menu() {
  case $(menu "Capture" "  Screenshot\n  Screenrecord\n󰴑  Text Extraction\n󰃉  Color\n󰌪  Overlays\n󰑋  Live Stream") in
  *Screenshot*) omarchy-capture-screenshot ;;
  *Screenrecord*) show_screenrecord_menu ;;
  *Text*) omarchy-capture-text-extraction ;;
  *Color*) pkill hyprpicker || hyprpicker -a ;;
   *Live*) livestream-toggle ;;
  *Overlays*) walker -m menus:screenrecord ;;
  *) back_to show_trigger_menu ;;
  esac
}
