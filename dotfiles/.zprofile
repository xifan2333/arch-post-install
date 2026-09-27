# ~/.zprofile: Executed for login shells.
# Automatically start River Wayland session via uwsm on tty1

if [[ -z "$WAYLAND_DISPLAY" && "${XDG_VTNR:-0}" -eq 1 ]]; then
    if command -v uwsm >/dev/null 2>&1; then
        exec uwsm start river
    elif command -v river >/dev/null 2>&1; then
        exec river
    fi
fi
