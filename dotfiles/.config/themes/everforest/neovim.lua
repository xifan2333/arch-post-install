return {
	"neanias/everforest-nvim",
	lazy = false,
	priority = 1000,
	config = function()
		vim.o.background = "dark"
		vim.g.everforest_background = "soft"
		vim.cmd.colorscheme("everforest")
	end,
}
