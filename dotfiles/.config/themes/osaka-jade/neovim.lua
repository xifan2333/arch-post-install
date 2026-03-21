return {
	"ribru17/bamboo.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		vim.o.background = "dark"
		require("bamboo").setup({})
		require("bamboo").load()
	end,
}
