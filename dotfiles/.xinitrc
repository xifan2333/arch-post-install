#!/bin/sh
#
# ~/.xinitrc - X11 session initialization script for suckless dwm session
#

# Merge X resources if present
if [ -f "$HOME/.Xresources" ]; then
	xrdb -merge "$HOME/.Xresources"
fi

# Start input method daemon (Fcitx5)
if command -v fcitx5 >/dev/null 2>&1; then
	fcitx5 -d &
fi

# Start X11 window manager (dwm)
exec dwm
