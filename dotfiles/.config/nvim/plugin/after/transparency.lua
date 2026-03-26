local function set_bg(groups, value)
  for _, group in ipairs(groups) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
    if ok and next(hl) then
      hl.bg = value
      vim.api.nvim_set_hl(0, group, hl)
    else
      vim.api.nvim_set_hl(0, group, { bg = value })
    end
  end
end
