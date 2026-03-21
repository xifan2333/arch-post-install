return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    opts = {
      formatters_by_ft = {
        bash = { "shfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        css = { "prettier" },
        go = { "gofmt" },
        html = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "prettier" },
        lua = { "stylua" },
        python = { "black" },
        sh = { "shfmt" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        vue = { "prettier" },
        yaml = { "prettier" },
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback",
      },
    },
  },
}
