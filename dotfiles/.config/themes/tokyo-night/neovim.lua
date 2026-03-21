return {
	"folke/tokyonight.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		vim.o.background = "dark"
		require("tokyonight").setup({ style = "night", transparent = false })
		vim.cmd.colorscheme("tokyonight")
	end,
}
