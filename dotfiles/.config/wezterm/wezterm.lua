-- WezTerm: host terminal only (font / theme / clipboard / window).
-- Layout, tabs, panes: Herdr (prefix Ctrl+a; direct chords Ctrl+Alt).
-- Do not bind Ctrl+Alt or Ctrl+a here — leave them for Herdr / apps.
-- Theme: ~/.config/current/wezterm.lua
-- Font:  ~/.config/wezterm/font.lua (font-sync-wezterm)

local wezterm = require("wezterm")
local config = wezterm.config_builder and wezterm.config_builder() or {}
local act = wezterm.action

local home = wezterm.home_dir
local theme_path = home .. "/.config/current/wezterm.lua"
local font_path = home .. "/.config/wezterm/font.lua"

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

-- Theme (colors)
local theme = load_lua_table(theme_path)
if theme and theme.colors then
  config.colors = theme.colors
end

-- Font overlay (written by font-sync-wezterm / font-set)
local font_cfg = load_lua_table(font_path) or {}
local font_name = font_cfg.font_family or "Maple Mono NF CN"
local font_size = font_cfg.font_size or 10.5

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

-- Window
config.window_padding = {
  left = 15,
  right = 15,
  top = 15,
  bottom = 15,
}
config.window_decorations = "TITLE | RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.scrollback_lines = 10000

-- Single-window host for Herdr: hide chrome when unused
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false

-- Cursor
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500
config.hide_mouse_cursor_when_typing = true

-- Wayland / behavior
config.enable_wayland = true
config.audible_bell = "Disabled"
config.check_for_updates = false
config.disable_default_mouse_bindings = false

-- No leader / layout keys. Clipboard + open new OS window only.
-- Ctrl+Alt* and Ctrl+A pass through to Herdr.
config.keys = {
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
    key = "Enter",
    mods = "SUPER|CTRL",
    action = act.SpawnWindow,
  },
}

return config
