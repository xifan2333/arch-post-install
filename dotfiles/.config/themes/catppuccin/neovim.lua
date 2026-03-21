return {
	"catppuccin/nvim",
	name = "catppuccin",
	lazy = false,
	priority = 1000,
	config = function()
		vim.o.background = "dark"
		require("catppuccin").setup({ flavour = "mocha" })
		vim.cmd.colorscheme("catppuccin")
	end,
}
