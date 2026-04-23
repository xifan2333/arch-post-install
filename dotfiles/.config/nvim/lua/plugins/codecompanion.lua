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
        xifan = function()
          local auth = vim.fn.readfile(vim.fn.expand("~/.codex/auth.json"))
          local key = vim.fn.json_decode(table.concat(auth)).OPENAI_API_KEY
          return require("codecompanion.adapters").extend("openai", {
            env = { api_key = key },
            url = "http://10.0.0.253:3000/v1/chat/completions",
            schema = {
              model = { default = "gpt-4.1" },
            },
          })
        end,
      },
      strategies = {
        chat = { adapter = "xifan" },
        inline = { adapter = "xifan" },
      },
    },
  },
}
