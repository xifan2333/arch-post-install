local transparency_file = vim.fn.stdpath("config") .. "/plugin/after/transparency.lua"

local transparent_groups = {
  "Normal", "NormalFloat", "FloatBorder", "Pmenu", "Terminal",
  "EndOfBuffer", "FoldColumn", "Folded", "SignColumn", "NormalNC",
  "WhichKeyFloat",
  "NotifyINFOBody", "NotifyERRORBody", "NotifyWARNBody",
  "NotifyTRACEBody", "NotifyDEBUGBody",
  "NotifyINFOTitle", "NotifyERRORTitle", "NotifyWARNTitle",
  "NotifyTRACETitle", "NotifyDEBUGTitle",
  "NotifyINFOBorder", "NotifyERRORBorder", "NotifyWARNBorder",
  "NotifyTRACEBorder", "NotifyDEBUGBorder",
}

local function reload_theme()
  local theme_file = vim.fn.expand("~/.config/current/neovim.lua")
  if vim.fn.filereadable(theme_file) ~= 1 then
    return
  end

  local real = vim.uv.fs_realpath(theme_file)
  if real == vim.g._loaded_theme_path then
    return
  end

  -- Reset transparent groups before clearing
  for _, group in ipairs(transparent_groups) do
    vim.api.nvim_set_hl(0, group, {})
  end

  vim.cmd("highlight clear")

  package.loaded["plugins.theme"] = nil
  local spec = dofile(theme_file)
  if spec and spec.config then
    spec.config()
  end

  vim.g._loaded_theme_path = real

  -- Re-apply transparency after colorscheme is fully set
  vim.schedule(function()
    if vim.fn.filereadable(transparency_file) == 1 then
      vim.cmd.source(transparency_file)
    end
    vim.cmd("redraw!")
  end)
end

vim.api.nvim_create_user_command("ThemeReload", reload_theme, {})

-- Watch ~/.config/ directory for symlink changes to "current"
local watch_dir = vim.fn.expand("~/.config")
local w = vim.uv.new_fs_event()
if w then
  w:start(watch_dir, {}, function(err, filename)
    if err or filename ~= "current" then return end
    vim.schedule(reload_theme)
  end)
end
