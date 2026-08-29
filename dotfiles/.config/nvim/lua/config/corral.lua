-- Corral diff review helpers for Neovim terminal buffers.
--
-- Copy this file into your Neovim config (for example,
-- ~/.config/nvim/lua/config/corral.lua) and load it with:
--
--   require("config.corral")

local group = vim.api.nvim_create_augroup("CorralDiffReview", { clear = true })
local change_pattern = [[\v(^\s*\d+\s*⋮\s*│|^\s*⋮\s*\d+\s*│|^\s*\d+\s*[-+])]]

vim.api.nvim_create_autocmd("TermOpen", {
  group = group,
  desc = "Configure navigation for Corral diff previews",
  callback = function(event)
    vim.keymap.set("n", ".", function()
      vim.fn.search(change_pattern, "W")
    end, {
      buffer = event.buf,
      desc = "Next diff change",
      silent = true,
    })

    vim.keymap.set("n", ",", function()
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
  end,
})
