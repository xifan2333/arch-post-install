-- Corral diff review helpers for Neovim terminal buffers.
--
-- Copy this file into your Neovim config (for example,
-- ~/.config/nvim/lua/config/corral.lua) and load it with:
--
--   require("config.corral")
--
-- Only buffers created by Corral (which set b:corral_preview = 1) get the
-- ,/. diff-jump keymaps, so a terminal you open manually is left untouched.

local group = vim.api.nvim_create_augroup("CorralDiffReview", { clear = true })
local change_pattern = [[\v(^\s*\d+\s*⋮\s*│|^\s*⋮\s*\d+\s*│|^\s*\d+\s*[-+])]]

local function apply(event)
  if not vim.b[event.buf].corral_preview then
    return
  end

  -- Keep j/k for line scrolling; use ←/→ to jump across changes.
  vim.keymap.set("n", "<Right>", function()
    vim.fn.search(change_pattern, "W")
  end, {
    buffer = event.buf,
    desc = "Next diff change",
    silent = true,
  })
  vim.keymap.set("n", "<Left>", function()
    vim.fn.search(change_pattern, "bW")
  end, {
    buffer = event.buf,
    desc = "Previous diff change",
    silent = true,
  })

  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(event.buf) then
      pcall(vim.fn.search, change_pattern, "W")
    end
  end, 120)
end

vim.api.nvim_create_autocmd("TermOpen", {
  group = group,
  desc = "Configure navigation for Corral diff previews",
  callback = function(event)
    -- Corral sets b:corral_preview after :terminal runs (TermOpen fires first),
    -- so check it a tick later rather than synchronously.
    vim.defer_fn(function()
      apply(event)
    end, 20)
  end,
})
