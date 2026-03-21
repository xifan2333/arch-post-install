return {
	"navarasu/onedark.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		require("onedark").setup({ style = "light" })
		vim.o.background = "light"
		vim.cmd.colorscheme("onedark")
	end,
}
