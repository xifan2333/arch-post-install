return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", desc = "AI Chat" },
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>", desc = "AI Actions", mode = { "n", "v" } },
    },
    opts = {
      adapters = {
        http = {
          xifan = function()
            local auth = vim.fn.readfile(vim.fn.expand("~/.codex/auth.json"))
            local key = vim.fn.json_decode(table.concat(auth)).OPENAI_API_KEY
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                api_key = key,
                url = "http://10.0.0.253:3000",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = { default = "gpt-5.4" },
              },
            })
          end,
        },
      },
      interactions = {
        chat = { adapter = "xifan" },
        inline = { adapter = "xifan" },
      },
    },
  },
}
