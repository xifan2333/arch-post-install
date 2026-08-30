-- Personal keybindings on top of Omarchy defaults.
-- View the effective bindings with: omarchy menu keybindings --print

-- Daily-driver applications. Keep Omarchy's default bindings available where
-- they do not conflict, while restoring the old muscle-memory shortcuts.
hl.unbind("SUPER + RETURN")
o.bind(
  "SUPER + RETURN",
  "Terminal",
  [[uwsm-app -- wezterm start --cwd "$(omarchy-cmd-terminal-cwd)"]]
)
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + M", "Music", { launch = "/opt/Listen1/listen1", focus = "^Listen1$" })
o.bind("SUPER + N", "Editor", { omarchy = "editor" })
o.bind("SUPER + D", "Docker", { tui = "lazydocker" })

hl.unbind("SUPER + ALT + RETURN")
o.bind(
  "SUPER + ALT + RETURN",
  "Herdr",
  [[uwsm-app -- wezterm start --cwd "$(omarchy-cmd-terminal-cwd)" -- herdr]]
)
o.bind("SUPER + ALT + E", "File manager (cwd)", { omarchy = "nautilus-cwd" })
o.bind("SUPER + ALT + B", "Browser (private)", { omarchy = "browser --private" })
o.bind("SUPER + ALT + M", "Music TUI", { tui = "musicfox", focus = true })
o.bind("SUPER + ALT + O", "Obsidian", { launch = "obsidian", focus = "^obsidian$" })
o.bind("SUPER + ALT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- Window behavior and legacy screenshot shortcuts.
o.bind("F11", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("SUPER + mouse:274", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
o.bind("SHIFT + PRINT", "Screenshot fullscreen", "omarchy capture screenshot fullscreen")
o.bind("SUPER + SHIFT + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + SHIFT + ESCAPE", "Lock screen", "omarchy system lock")

-- Capture and livestream shortcuts. These intentionally replace selected
-- Omarchy defaults so every mutation continues to go through capture-router.
hl.unbind("ALT + PRINT")
o.bind("ALT + PRINT", "Capture menu", "capture-router menu")

hl.unbind("SUPER + CTRL + PRINT")
o.bind("CTRL + PRINT", "Extract text (OCR) from screenshot", "capture-text-extraction")

o.bind(
  "SUPER + R",
  "Screenrecording toggle",
  "capture-router recording toggle --with-desktop-audio --with-microphone-audio"
)
o.bind("SUPER + ALT + R", "Live Stream", "capture-router livestream toggle portal")
o.bind("SUPER + SHIFT + R", "Live Stream config", "capture-router config")

o.bind("SUPER + ALT + V", "Camera overlay toggle", "capture-router overlay camera")
hl.unbind("SUPER + ALT + K")
o.bind("SUPER + ALT + K", "Keys overlay toggle", "capture-router overlay keys")
o.bind("SUPER + ALT + C", "Captions overlay toggle", "capture-router overlay captions")
o.bind("SUPER + ALT + T", "Title overlay toggle", "capture-router overlay title")
o.bind("SUPER + SHIFT + T", "Title overlay config", "capture-router overlay edit")
