-- 精确统计汉字数（U+4E00-U+9FFF，字节级 UTF-8 匹配）
-- 跳过以 -- 开头的注释行和 <!-- HTML 注释 -->
local function hanzi_count()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local n = 0
  for _, line in ipairs(lines) do
    if not line:match("^%s*%-%-") and not line:match("^%s*<!") then
      n = n + select(2, line:gsub("[\228][\184-\191][\128-\191]", "")) -- E4 段
      n = n + select(2, line:gsub("[\229-\232][\128-\191][\128-\191]", "")) -- E5-E8 段
      n = n + select(2, line:gsub("[\233][\128-\191][\128-\191]", "")) -- E9 段
    end
  end
  return n
end

return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        globalstatus = true,
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        refresh = { "TextChanged", "TextChangedI", "CursorHold", "ModeChanged" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          "encoding",
          "fileformat",
          "filetype",
          {
            function()
              return "字 " .. hanzi_count()
            end,
            -- 只在 markdown / txt 下显示
            cond = function()
              return vim.tbl_contains({ "markdown", "text" }, vim.bo.filetype)
            end,
          },
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
}
