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
