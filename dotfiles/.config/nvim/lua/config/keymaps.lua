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
