-- WezTerm configuration
-- Theme colors loaded from current theme (~/.config/current/wezterm.lua)
-- Font overlay written by font-sync-wezterm (~/.config/wezterm/font.lua)

local wezterm = require("wezterm")
local config = wezterm.config_builder and wezterm.config_builder() or {}

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

-- Font overlay
local font_cfg = load_lua_table(font_path) or {}
local font_name = font_cfg.font_family or "CaskaydiaMono Nerd Font Mono"
local font_size = font_cfg.font_size or 10.5

-- Primary Latin/nerd font + monospaced CJK (更纱等宽).
-- Keep CJK on Sarasa Mono so Chinese stays dual-width monospaced, not proportional.
config.font = wezterm.font_with_fallback({
  font_name,
  "Sarasa Mono SC",
  "Sarasa Mono Slab SC",
  "Noto Sans Mono CJK SC",
  "Noto Color Emoji",
})
config.font_size = font_size
config.use_cap_height_to_scale_fallback_fonts = true
config.allow_square_glyphs_to_overflow_width = "Never"
config.warn_about_missing_glyphs = false

-- Window
config.window_padding = {
  left = 15,
  right = 15,
  top = 15,
  bottom = 15,
}
config.window_decorations = "TITLE | RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true
config.scrollback_lines = 10000

-- Cursor
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500
config.hide_mouse_cursor_when_typing = true

-- Wayland / behavior
config.enable_wayland = true
config.audible_bell = "Disabled"
config.check_for_updates = false

-- Keys (aligned with kitty defaults in this setup)
config.keys = {
  {
    key = "v",
    mods = "CTRL|SHIFT",
    action = wezterm.action.PasteFrom("Clipboard"),
  },
  {
    key = "c",
    mods = "CTRL|SHIFT",
    action = wezterm.action.CopyTo("Clipboard"),
  },
  {
    key = "Enter",
    mods = "SUPER|CTRL",
    action = wezterm.action.SpawnWindow,
  },
}

return config
