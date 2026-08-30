-- WezTerm host terminal for Omarchy.
-- Theme: ~/.local/state/omarchy/current/theme/wezterm.lua  (omarchy themed/*.tpl)
-- Font:  ~/.config/wezterm/font.lua                 (omarchy font-set hook)

local wezterm = require("wezterm")
local config = wezterm.config_builder and wezterm.config_builder() or {}
local act = wezterm.action

local home = wezterm.home_dir
local theme_path = home .. "/.local/state/omarchy/current/theme/wezterm.lua"
local font_path = home .. "/.config/wezterm/font.lua"

-- Reload when Omarchy rewrites theme/font overlays without touching this file.
wezterm.add_to_config_reload_watch_list(theme_path)
wezterm.add_to_config_reload_watch_list(font_path)

local function load_lua_table(path)
  local ok, result = pcall(function()
    local chunk, err = loadfile(path)
    if not chunk then
      error(err or ("failed to load " .. path))
    end
    local value = chunk()
    if type(value) ~= "table" then
      error(path .. " did not return a table")
    end
    return value
  end)
  if ok then
    return result
  end
  wezterm.log_warn("wezterm config load failed: " .. tostring(result))
  return nil
end

local theme = load_lua_table(theme_path)
if theme and theme.colors then
  config.colors = theme.colors
end

local font_cfg = load_lua_table(font_path) or {}
local font_name = font_cfg.font_family or "Maple Mono NF"
local font_size = font_cfg.font_size or 9.0

local function latin_font(attrs)
  attrs = attrs or {}
  return wezterm.font_with_fallback({
    {
      family = font_name,
      weight = attrs.weight or "Regular",
      style = attrs.style or "Normal",
      harfbuzz_features = { "calt=0", "clig=0", "liga=0" },
    },
    {
      family = "Sarasa Mono SC",
      weight = attrs.weight or "Regular",
      style = attrs.style or "Normal",
    },
    "Sarasa Mono SC",
    "Noto Color Emoji",
  })
end

config.font = latin_font({ weight = "Regular", style = "Normal" })
config.font_size = font_size
config.line_height = 1.0
config.cell_width = 1.0
config.use_cap_height_to_scale_fallback_fonts = false
config.allow_square_glyphs_to_overflow_width = "Never"
config.warn_about_missing_glyphs = false

config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

config.font_rules = {
  {
    intensity = "Bold",
    italic = false,
    font = latin_font({ weight = "Bold", style = "Normal" }),
  },
  {
    intensity = "Bold",
    italic = true,
    font = latin_font({ weight = "Bold", style = "Italic" }),
  },
  {
    intensity = "Normal",
    italic = true,
    font = latin_font({ weight = "Regular", style = "Italic" }),
  },
  {
    intensity = "Half",
    italic = false,
    font = latin_font({ weight = "Regular", style = "Normal" }),
  },
  {
    intensity = "Half",
    italic = true,
    font = latin_font({ weight = "Regular", style = "Italic" }),
  },
}

-- Window (match Omarchy terminal chrome: no CSD, modest padding)
config.window_padding = {
  left = 14,
  right = 14,
  top = 14,
  bottom = 14,
}
config.window_decorations = "NONE"
config.window_close_confirmation = "NeverPrompt"
config.scrollback_lines = 10000

config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.75,
}

-- Cursor
config.default_cursor_style = "SteadyBlock"
config.hide_mouse_cursor_when_typing = true

-- Wayland / behavior
config.enable_wayland = true
config.audible_bell = "Disabled"
config.check_for_updates = false
config.automatically_reload_config = true
config.enable_kitty_graphics = true
config.disable_default_mouse_bindings = false

config.keys = {
  -- Clipboard
  {
    key = "v",
    mods = "CTRL|SHIFT",
    action = act.PasteFrom("Clipboard"),
  },
  {
    key = "c",
    mods = "CTRL|SHIFT",
    action = act.CopyTo("Clipboard"),
  },
  {
    key = "Insert",
    mods = "SHIFT",
    action = act.PasteFrom("Clipboard"),
  },
  {
    key = "Insert",
    mods = "CTRL",
    action = act.CopyTo("Clipboard"),
  },
  {
    key = "Enter",
    mods = "SUPER|CTRL",
    action = act.SpawnWindow,
  },

  -- Tabs (Ctrl+Alt)
  {
    key = "f",
    mods = "CTRL|ALT",
    action = act.SpawnTab("CurrentPaneDomain"),
  },
  {
    key = "c",
    mods = "CTRL|ALT",
    action = act.SpawnTab("CurrentPaneDomain"),
  },
  {
    key = "[",
    mods = "CTRL|ALT",
    action = act.ActivateTabRelative(-1),
  },
  {
    key = "]",
    mods = "CTRL|ALT",
    action = act.ActivateTabRelative(1),
  },
  {
    key = "w",
    mods = "CTRL|ALT",
    action = act.CloseCurrentTab({ confirm = false }),
  },

  -- Ctrl+Alt+arrows must be bound, or WezTerm leaks CSI sequences into the shell.
  {
    key = "LeftArrow",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "DownArrow",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "UpArrow",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "RightArrow",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Right"),
  },
  {
    key = "h",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "j",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "k",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "l",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Right"),
  },
  -- - horizontal split (top/bottom); = vertical split (left/right)
  {
    key = "-",
    mods = "CTRL|ALT",
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "=",
    mods = "CTRL|ALT",
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "z",
    mods = "CTRL|ALT",
    action = act.TogglePaneZoomState,
  },
  {
    key = "x",
    mods = "CTRL|ALT",
    action = act.CloseCurrentPane({ confirm = false }),
  },
}

for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = "CTRL|ALT",
    action = act.ActivateTab(i - 1),
  })
end

return config
