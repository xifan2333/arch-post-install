-- Personal input overrides on top of Omarchy defaults.

-- Keep Caps Lock as Escape instead of using Omarchy's Compose-key default.
hl.config({
  input = {
    kb_options = "caps:swapescape",
  },
})

-- Omarchy covers its stock terminals; WezTerm uses a different Wayland class.
o.window("org\\.wezfurlong\\.wezterm", { scroll_touchpad = 1.5 })
