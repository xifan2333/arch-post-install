local function open_cheatsheet()
  local path = vim.fn.stdpath("config") .. "/cheatsheet.txt"
  local lines = vim.fn.readfile(path)
  local items = {}
  for _, line in ipairs(lines) do
    if line ~= "" then
      local cat, mode, key, desc = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(.+)$")
      if cat then
        table.insert(items, {
          text = string.format("[%s] [%s] %-22s %s", cat, mode, key, desc),
          cat = cat,
          mode = mode,
          key = key,
          desc = desc,
        })
      end
    end
  end
  Snacks.picker({
    title = "Cheatsheet",
    items = items,
    confirm = function() end,
    preview = "none",
    format = function(item)
      return {
        { "[" .. item.cat .. "]", "Special" },
        { " " },
        { "[" .. item.mode .. "]", "DiagnosticInfo" },
        { " " },
        { item.key, "Title" },
        { "  " },
        { item.desc, "Comment" },
      }
    end,
  })
end

vim.keymap.set("n", "<C-/>", open_cheatsheet, { desc = "Cheatsheet" })

return {}
