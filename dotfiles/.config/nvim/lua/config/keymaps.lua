local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>")

map("n", "<leader>e", function()
  Snacks.explorer()
end, { desc = "Explorer" })

map("n", "<leader>ff", function()
  Snacks.picker.files()
end, { desc = "Find Files" })

map("n", "<leader>fg", function()
  Snacks.picker.grep()
end, { desc = "Find Text" })

map("n", "<leader>fb", function()
  Snacks.picker.buffers()
end, { desc = "Buffers" })

map("n", "<leader>fr", function()
  Snacks.picker.recent()
end, { desc = "Recent Files" })

-- Buffer
map("n", "<leader>bn", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Close buffer" })

-- Save
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<CR><Esc>", { desc = "Save file" })

-- Format
map({ "n", "v" }, "<leader>cf", function()
  require("conform").format({ async = true })
end, { desc = "Format" })

-- Copy file path
map("n", "<leader>ya", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Copy absolute path" })

map("n", "<leader>yr", function()
  local path = vim.fn.expand("%:.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Copy relative path" })

-- Diff review in terminal buffers: ,/. (and n/p) to jump across change blocks, auto-jump on open
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(ev)
    local pat = [[\v(^\s*\d+\s*⋮\s*│|^\s*⋮\s*\d+\s*│|^\s*\d+\s*[-+])]]

    local function is_change(lnum)
      return lnum >= 1 and lnum <= vim.fn.line("$") and vim.fn.match(vim.fn.getline(lnum), pat) >= 0
    end

    local function jump_next_block()
      local start_pos = vim.api.nvim_win_get_cursor(0)
      local l = start_pos[1]
      if is_change(l) then
        while is_change(l) do
          l = l + 1
        end
        if l <= vim.fn.line("$") then
          vim.api.nvim_win_set_cursor(0, { l, 0 })
        else
          return
        end
      end
      if vim.fn.search(pat, "W") == 0 then
        vim.api.nvim_win_set_cursor(0, start_pos)
      end
    end

    local function jump_prev_block()
      local start_pos = vim.api.nvim_win_get_cursor(0)
      local l = start_pos[1]
      if is_change(l) then
        while is_change(l) do
          l = l - 1
        end
        if l >= 1 then
          vim.api.nvim_win_set_cursor(0, { l, 0 })
        else
          return
        end
      end
      if vim.fn.search(pat, "bW") > 0 then
        local top = vim.fn.line(".")
        while is_change(top - 1) do
          top = top - 1
        end
        vim.api.nvim_win_set_cursor(0, { top, 0 })
      else
        vim.api.nvim_win_set_cursor(0, start_pos)
      end
    end

    map("n", ".", jump_next_block, { buffer = ev.buf, desc = "Next diff block", silent = true })
    map("n", ",", jump_prev_block, { buffer = ev.buf, desc = "Previous diff block", silent = true })
    map("n", "n", jump_next_block, { buffer = ev.buf, desc = "Next diff block", silent = true })
    map("n", "p", jump_prev_block, { buffer = ev.buf, desc = "Previous diff block", silent = true })

    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(ev.buf) then
        pcall(jump_next_block)
      end
    end, 120)
  end,
})
