return {
	"catppuccin/nvim",
	name = "catppuccin",
	lazy = false,
	priority = 1000,
	config = function()
		require("catppuccin").setup({ flavour = "latte" })
		vim.o.background = "light"
		vim.cmd.colorscheme("catppuccin-latte")
	end,
}
