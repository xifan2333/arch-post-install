#
# ~/.zprofile
#

# Auto-start River with UWSM on tty1
if [ -z "${WAYLAND_DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
  exec uwsm start -F river
fi
