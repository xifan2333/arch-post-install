[general]
# Smart window resizing based on screenshot dimensions
resize = { mode = "smart" }
floating-hack = true

# Exit directly after copying or saving
early-exit = ["copy", "save"]

# Use standard Wayland clipboard
copy-command = "wl-copy"

# Default screenshot save path
output-filename = "~/Pictures/screenshots/annotated-%Y%m%d_%H%M%S.png"

# Keyboard action triggers
actions-on-enter = ["save-to-clipboard"]
actions-on-escape = ["exit"]

# Request borderless window from compositor
no-window-decoration = true

# Default active annotation tool on launch
initial-tool = "brush"

[color-palette]
palette = [
  "{{ red }}",
  "{{ orange }}",
  "{{ yellow }}",
  "{{ green }}",
  "{{ cyan }}",
  "{{ blue }}",
  "{{ magenta }}",
]
custom = [
  "{{ accent }}",
  "{{ selection }}",
  "{{ foreground }}",
  "{{ muted }}",
  "{{ darker_background }}",
]
