return {
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    opts = {
      explorer = {
        enabled = true,
        replace_netrw = true,
      },
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            git_status = true,
            trash = {
              cmd = { "gio", "trash" },
            },
          },
          files = {
            hidden = true,
            ignored = true,
          },
        },
      },
      dashboard = { enabled = true },
      quickfile = { enabled = true },
      scroll = { enabled = false },
      statuscolumn = { enabled = true },
    },
  },
}
