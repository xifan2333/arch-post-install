-- Personal keybindings on top of Omarchy defaults.
-- View the effective bindings with: omarchy menu keybindings --print

-- ============================================================================
-- Daily Applications (Win = primary, Win+Alt = secondary variant)
-- ============================================================================
hl.unbind("SUPER + RETURN")
o.bind(
  "SUPER + RETURN",
  "Terminal",
  [[uwsm-app -- wezterm start --cwd "$(omarchy-cmd-terminal-cwd)"]]
)
hl.unbind("SUPER + ALT + RETURN")
o.bind(
  "SUPER + ALT + RETURN",
  "Herdr",
  [[uwsm-app -- wezterm start --cwd "$(omarchy-cmd-terminal-cwd)" -- herdr]]
)

-- Browser (B)
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + ALT + B", "Browser (private)", { omarchy = "browser --private" })

-- Explorer / Files (E)
o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + ALT + E", "File manager (cwd)", { omarchy = "nautilus-cwd" })

-- Notes & Writing (N: Neovim / Obsidian / Typora)
o.bind("SUPER + N", "Editor", { omarchy = "editor" })
o.bind("SUPER + ALT + N", "Obsidian", { launch = "obsidian", focus = "^obsidian$" })
hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Typora", { launch = "typora --enable-wayland-ime" })

-- Music (M) & Docker (D)
o.bind("SUPER + M", "Music TUI", { tui = "musicfox", focus = true })
o.bind("SUPER + D", "Docker", { tui = "lazydocker" })

-- ============================================================================
-- Windows-Style System Controls (G / I / L / .)
--   (Super+C/V/X universal clipboard and Super+Ctrl+V clipboard manager stay stock)
-- ============================================================================
-- Win+G: Capture & recording menu (matches Windows Win+G Game Bar)
hl.unbind("SUPER + G")
o.bind("SUPER + G", "Recording menu", "omarchy menu toggle trigger.capture")

-- Win+I: System & settings menu (matches Windows Win+I)
o.bind("SUPER + I", "System menu", "omarchy-menu toggle system")

-- Win+L: Lock screen (matches Windows Win+L)
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock screen", "omarchy system lock")
o.bind("SUPER + SHIFT + ESCAPE", "Lock screen", "omarchy system lock")

-- Win+.: Emoji picker (matches Windows Win+.)
o.bind("SUPER + PERIOD", "Emoji", "omarchy-shell shell toggle omarchy.emojis")

-- Window controls
o.bind("F11", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("SUPER + mouse:274", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))

-- ============================================================================
-- Screenshots & Color (Print family)
-- ============================================================================
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "omarchy capture screenshot")
o.bind("SHIFT + PRINT", "Screenshot fullscreen", "omarchy capture screenshot fullscreen")
hl.unbind("SUPER + CTRL + PRINT")
o.bind("CTRL + PRINT", "Extract text (OCR) from screenshot", "capture-text-extraction")
hl.unbind("ALT + PRINT")
o.bind("ALT + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")

-- ============================================================================
-- Recording & Livestream (R family)
-- ============================================================================
o.bind(
  "SUPER + R",
  "Screenrecording toggle",
  "omarchy capture screenrecording --with-desktop-audio --with-microphone-audio"
)
o.bind("SUPER + ALT + R", "Live Stream", "livestream toggle portal")
o.bind("SUPER + SHIFT + R", "Live Stream config", "omarchy-shell xifan.livestream-config toggle")

-- ============================================================================
-- Overlays (Win+Alt = toggle use, Win+Shift = HUD config)
--   S = Subtitles (captions)
--   W = Webcam (camera PiP)
--   K = Keystrokes (keys)
--   T = Title (title card)
-- ============================================================================
-- S: Subtitles (Captions)
hl.unbind("SUPER + ALT + S")
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + ALT + S", "Captions overlay toggle", "omarchy-shell xifan.overlay-captions toggle")
o.bind("SUPER + SHIFT + S", "Captions overlay config", "omarchy-shell xifan.overlay-captions edit")

-- W: Webcam (Camera)
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + ALT + W", "Camera overlay toggle", "omarchy-shell xifan.overlay-camera toggle")
o.bind("SUPER + SHIFT + W", "Camera overlay config", "omarchy-shell xifan.overlay-camera edit")

-- K: Keys (Keystrokes)
hl.unbind("SUPER + ALT + K")
o.bind("SUPER + ALT + K", "Keys overlay toggle", "omarchy-shell xifan.overlay-keys toggle")
o.bind("SUPER + SHIFT + K", "Keys overlay config", "omarchy-shell xifan.overlay-keys edit")

-- T: Title (Title card)
o.bind("SUPER + ALT + T", "Title overlay toggle", "omarchy-shell xifan.overlay-title toggle")
o.bind("SUPER + SHIFT + T", "Title overlay config", "omarchy-shell xifan.overlay-title edit")
