return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  opts = {
    options = {
      close_command = "bdelete! %d",
      always_show_bufferline = false,
      diagnostics = "nvim_lspconfig",
      offsets = {
        {
          filetype = "snacks_layout_box",
          text = "Explorer",
          highlight = "Directory",
          text_align = "left",
        },
      },
    },
  },
}
