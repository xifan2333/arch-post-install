
vim.api.nvim_create_autocmd("BufReadPre", {
  group = vim.api.nvim_create_augroup("user-xdg-open", { clear = true }),
  callback = function(args)
    local file = args.file
    if not file or file == "" or file:match("^%w+://") then return end
    if vim.fn.filereadable(file) == 0 then return end
    local encoding = vim.fn.system("file --mime-encoding -b " .. vim.fn.shellescape(file)):gsub("%s+$", "")
    if encoding == "binary" then
      local mime = vim.fn.system("file --mime-type -b " .. vim.fn.shellescape(file)):gsub("%s+$", "")
      if not mime:match("^image/") then
        vim.fn.jobstart({ "xdg-open", file }, { detach = true })
        vim.schedule(function()
          vim.cmd("bwipeout!")
        end)
      end
    end
  end,
})


vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("user-highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
  callback = function(args)
    local map = function(lhs, rhs, desc, mode)
      mode = mode or "n"
      vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "Goto Definition")
    map("gr", vim.lsp.buf.references, "Goto References")
    map("gi", vim.lsp.buf.implementation, "Goto Implementation")
    map("K", vim.lsp.buf.hover, "Hover")
    map("<leader>rn", vim.lsp.buf.rename, "Rename")
    map("<leader>ca", vim.lsp.buf.code_action, "Code Action", { "n", "v" })
    map("<leader>fd", vim.diagnostic.open_float, "Line Diagnostics")
    map("[d", vim.diagnostic.goto_prev, "Prev Diagnostic")
    map("]d", vim.diagnostic.goto_next, "Next Diagnostic")
  end,
})
