-- Personal window rules on top of Omarchy defaults.
-- Current syntax: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Give WezTerm the same terminal treatment as Omarchy's stock terminals.
o.window("org\\.wezfurlong\\.wezterm", { tag = "+terminal" })
o.window("org\\.wezfurlong\\.wezterm", { tag = "-default-opacity" })
o.window("org\\.wezfurlong\\.wezterm", { opacity = "0.985 0.96" })

-- Float and center custom GTK configuration dialogs.
o.window("^livestream-config$", {
  float = true,
  center = true,
})
