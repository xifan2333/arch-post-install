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

-- Font overlay (written by font-sync-wezterm / font-set)
local font_cfg = load_lua_table(font_path) or {}
local font_name = font_cfg.font_family or "Maple Mono NF CN"
local font_size = font_cfg.font_size or 10.5

-- Explicit family+weight so WezTerm does not silently pick another face
-- (ExtraLight / Propo / wrong family) for the configured font.
local function latin_font(attrs)
  attrs = attrs or {}
  return wezterm.font_with_fallback({
    {
      family = font_name,
      weight = attrs.weight or "Regular",
      style = attrs.style or "Normal",
      harfbuzz_features = { "calt=0", "clig=0", "liga=0" },
    },
    -- Chinese: monospaced 更纱 only
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

-- Kitty-like rasterization: Normal FreeType hinting thins strokes and looks
-- jagged on this Intel/Wayland setup. Light hinting keeps stem weight; LCD
-- subpixel AA softens edges. (Tradeoff: no per-glyph alpha on text color.)
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

-- Match kitty: bold/italic stay on the same configured family, no ExtraLight dim face.
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
-- Match kitty: confirm_os_window_close 0
config.window_close_confirmation = "NeverPrompt"
config.scrollback_lines = 10000

-- Mux / tab bar (tmux-like)
-- Prefer built-in mux over nesting tmux so image protocols work cleanly.
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_and_split_indices_are_zero_based = false
config.show_new_tab_button_in_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.75,
}

-- Cursor
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500
config.hide_mouse_cursor_when_typing = true

-- Wayland / behavior
config.enable_wayland = true
config.audible_bell = "Disabled"
config.check_for_updates = false

-- Mouse (tmux: set -g mouse on)
config.disable_default_mouse_bindings = false

local act = wezterm.action

-- tmux prefix is C-a
-- Longer timeout: people often keep Ctrl held after C-a (tmux muscle memory).
config.leader = {
  key = "a",
  mods = "CTRL",
  timeout_milliseconds = 2000,
}

-- Bind both LEADER and LEADER|CTRL so `C-a` then `=` works whether Ctrl
-- is released or still held (common failure mode that feels "not deployed").
local function leader_bind(key, action, extra_mods)
  extra_mods = extra_mods or ""
  local mods = { "LEADER", "LEADER|CTRL" }
  if extra_mods ~= "" then
    mods = {
      "LEADER|" .. extra_mods,
      "LEADER|CTRL|" .. extra_mods,
    }
  end
  local bindings = {}
  for _, m in ipairs(mods) do
    table.insert(bindings, { key = key, mods = m, action = action })
  end
  return bindings
end

local function extend_keys(list, bindings)
  for _, b in ipairs(bindings) do
    table.insert(list, b)
  end
end

-- Keys: clipboard + tmux-style leader map from ~/.tmux.conf
config.keys = {
  -- Clipboard (kitty-aligned)
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

  -- Non-leader tab nav (tmux: M-Left / M-Right)
  {
    key = "LeftArrow",
    mods = "ALT",
    action = act.ActivateTabRelative(-1),
  },
  {
    key = "RightArrow",
    mods = "ALT",
    action = act.ActivateTabRelative(1),
  },

  -- Non-leader pane nav: Alt+hjkl + Alt+方向键 一键切面板，不用先按 C-a
  {
    key = "h",
    mods = "ALT",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "j",
    mods = "ALT",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "k",
    mods = "ALT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "l",
    mods = "ALT",
    action = act.ActivatePaneDirection("Right"),
  },
  {
    key = "LeftArrow",
    mods = "ALT",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "DownArrow",
    mods = "ALT",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "UpArrow",
    mods = "ALT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "RightArrow",
    mods = "ALT",
    action = act.ActivatePaneDirection("Right"),
  },

  -- Non-leader pane resize: Alt+Shift+hjkl 或 Alt+Shift+方向键
  {
    key = "h",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Left", 5 }),
  },
  {
    key = "j",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Down", 5 }),
  },
  {
    key = "k",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Up", 5 }),
  },
  {
    key = "l",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Right", 5 }),
  },
  {
    key = "LeftArrow",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Left", 5 }),
  },
  {
    key = "DownArrow",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Down", 5 }),
  },
  {
    key = "UpArrow",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Up", 5 }),
  },
  {
    key = "RightArrow",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Right", 5 }),
  },

  -- Non-leader zoom / close pane
  {
    key = "Enter",
    mods = "ALT",
    action = act.TogglePaneZoomState,
  },
  {
    key = "x",
    mods = "ALT",
    action = act.CloseCurrentPane({ confirm = false }),
  },
}

-- Send real Ctrl-a through (tmux: bind C-a send-prefix)
extend_keys(config.keys, leader_bind("a", act.SendKey({ key = "a", mods = "CTRL" })))

-- Reload
extend_keys(config.keys, leader_bind("r", act.ReloadConfiguration))

-- Split panes (tmux: = horizontal / - vertical)
extend_keys(
  config.keys,
  leader_bind("=", act.SplitHorizontal({ domain = "CurrentPaneDomain" }))
)
extend_keys(
  config.keys,
  leader_bind("-", act.SplitVertical({ domain = "CurrentPaneDomain" }))
)
-- US keyboard muscle memory sometimes hits Shift+= for "plus" when splitting
extend_keys(
  config.keys,
  leader_bind("=", act.SplitHorizontal({ domain = "CurrentPaneDomain" }), "SHIFT")
)
extend_keys(
  config.keys,
  leader_bind("+", act.SplitHorizontal({ domain = "CurrentPaneDomain" }))
)

-- Pane navigation (tmux: h j k l)
extend_keys(config.keys, leader_bind("h", act.ActivatePaneDirection("Left")))
extend_keys(config.keys, leader_bind("j", act.ActivatePaneDirection("Down")))
extend_keys(config.keys, leader_bind("k", act.ActivatePaneDirection("Up")))
extend_keys(config.keys, leader_bind("l", act.ActivatePaneDirection("Right")))

-- Pane resizing (tmux: H J K L by 5)
extend_keys(config.keys, leader_bind("H", act.AdjustPaneSize({ "Left", 5 })))
extend_keys(config.keys, leader_bind("J", act.AdjustPaneSize({ "Down", 5 })))
extend_keys(config.keys, leader_bind("K", act.AdjustPaneSize({ "Up", 5 })))
extend_keys(config.keys, leader_bind("L", act.AdjustPaneSize({ "Right", 5 })))
-- Also allow LEADER|SHIFT+h/j/k/l for resize without releasing shift carefully
extend_keys(config.keys, leader_bind("h", act.AdjustPaneSize({ "Left", 5 }), "SHIFT"))
extend_keys(config.keys, leader_bind("j", act.AdjustPaneSize({ "Down", 5 }), "SHIFT"))
extend_keys(config.keys, leader_bind("k", act.AdjustPaneSize({ "Up", 5 }), "SHIFT"))
extend_keys(config.keys, leader_bind("l", act.AdjustPaneSize({ "Right", 5 }), "SHIFT"))

-- Layout cycle (tmux: Space next-layout ≈ rotate panes)
extend_keys(config.keys, leader_bind(" ", act.RotatePanes("Clockwise")))

-- Zoom / close / new tab
extend_keys(config.keys, leader_bind("z", act.TogglePaneZoomState))
extend_keys(config.keys, leader_bind("x", act.CloseCurrentPane({ confirm = false })))
extend_keys(config.keys, leader_bind("c", act.SpawnTab("CurrentPaneDomain")))
extend_keys(config.keys, leader_bind("&", act.CloseCurrentTab({ confirm = false }), "SHIFT"))

-- Copy mode
extend_keys(config.keys, leader_bind("[", act.ActivateCopyMode))
extend_keys(config.keys, leader_bind("]", act.PasteFrom("PrimarySelection")))

-- Tab navigation
extend_keys(config.keys, leader_bind("p", act.ActivateTabRelative(-1)))
extend_keys(config.keys, leader_bind("n", act.ActivateTabRelative(1)))

-- Help
extend_keys(config.keys, leader_bind("?", act.ActivateCommandPalette, "SHIFT"))
extend_keys(
  config.keys,
  leader_bind("/", act.SplitHorizontal({ args = { "man", "wezterm" } }))
)

-- Leader + 1..9 → tab N (1-based, matching tmux base-index 1)
for i = 1, 9 do
  extend_keys(config.keys, leader_bind(tostring(i), act.ActivateTab(i - 1)))
end

-- Keep default copy/search tables; layer vi-ish yank/exit helpers on top.
local copy_mode = {}
if wezterm.gui then
  copy_mode = wezterm.gui.default_key_tables().copy_mode
end
local function add_copy_mode(binding)
  table.insert(copy_mode, binding)
end
add_copy_mode({
  key = "y",
  mods = "NONE",
  action = act.Multiple({
    { CopyTo = "ClipboardAndPrimarySelection" },
    { CopyMode = "Close" },
  }),
})
add_copy_mode({ key = "q", mods = "NONE", action = act.CopyMode("Close") })
config.key_tables = {
  copy_mode = copy_mode,
}

return config
