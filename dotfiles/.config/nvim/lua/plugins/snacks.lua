return {
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    opts = {
      explorer = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            git_status = true,
          },
          files = {
            hidden = true,
            ignored = true,
          },
        },
      },
      quickfile = { enabled = true },
      scroll = { enabled = false },
      statuscolumn = { enabled = true },
    },
  },
}
