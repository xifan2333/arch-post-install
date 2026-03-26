return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {},
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason.nvim" },
    event = "BufReadPre",
    opts = {
      ensure_installed = {
        -- LSP servers
        "bashls",
        "clangd",
        "gopls",
        "jsonls",
        "lua_ls",
        "pyright",
        "taplo",
        "ts_ls",
        "vue_ls",
        "yamlls",
        -- Formatters
        "black",
        "prettier",
        "shfmt",
        "stylua",
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim", "nvim-lspconfig" },
    event = "BufReadPre",
    opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok, blink = pcall(require, "blink.cmp")
      if ok then
        capabilities = blink.get_lsp_capabilities(capabilities)
      end
      local servers = {
        bashls = {},
        clangd = {},
        gopls = {},
        jsonls = {},
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
        pyright = {},
        taplo = {},
        ts_ls = {},
        vue_ls = {},
        yamlls = {},
      }

      for name, config in pairs(servers) do
        config.capabilities = capabilities
        vim.lsp.config(name, config)
        vim.lsp.enable(name)
      end
    end,
  },
}
