local enabled = true

if vim.fn.executable("busctl") ~= 1 then
  return {}
end

local group = vim.api.nvim_create_augroup("user-rime-switch", { clear = true })

-- 过滤特殊 buffer（终端、预览弹窗、浮窗等）
local function should_manage_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.b[buf].corral_preview then
    return false
  end
  local bt = vim.bo[buf].buftype
  if bt == "terminal" or bt == "nofile" or bt == "prompt" or bt == "quickfix" then
    return false
  end
  return true
end

-- 异步查询 Rime 是否处于 ASCII 模式
local function get_ascii_mode(callback)
  vim.system({
    "busctl",
    "--user",
    "call",
    "org.fcitx.Fcitx5",
    "/rime",
    "org.fcitx.Fcitx.Rime1",
    "IsAsciiMode",
  }, { text = true }, function(out)
    if out.code == 0 and out.stdout then
      local is_ascii = out.stdout:match("^b%s+true") ~= nil
      callback(is_ascii)
    end
  end)
end

-- 异步设置 Rime ASCII 模式
local function set_ascii_mode(ascii)
  local state_str = ascii and "true" or "false"
  vim.system({
    "busctl",
    "--user",
    "call",
    "org.fcitx.Fcitx5",
    "/rime",
    "org.fcitx.Fcitx.Rime1",
    "SetAsciiMode",
    "b",
    state_str,
  })
end

-- 确保在 Normal 模式下（启动、切 buffer、获焦时）始终处于 ASCII (英文) 模式
vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter", "FocusGained" }, {
  group = group,
  callback = function(args)
    if not enabled or not should_manage_buffer(args.buf) then
      return
    end
    local mode = vim.api.nvim_get_mode().mode
    if mode == "n" then
      get_ascii_mode(function(is_ascii)
        if not is_ascii then
          set_ascii_mode(true)
        end
      end)
    end
  end,
  desc = "Ensure Rime ASCII mode in normal mode",
})

-- 离开插入模式：记录当前 buffer 是否处于中文，并切回 ASCII 模式
vim.api.nvim_create_autocmd("InsertLeave", {
  group = group,
  callback = function(args)
    if not enabled or not should_manage_buffer(args.buf) then
      return
    end
    local buf = args.buf
    get_ascii_mode(function(is_ascii)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.b[buf].rime_was_chinese = not is_ascii
        end
      end)
      if not is_ascii then
        set_ascii_mode(true)
      end
    end)
  end,
  desc = "Save Rime state and switch to ASCII on InsertLeave",
})

-- 进入插入模式：如果该 buffer 离开插入模式前是中文，恢复中文模式
vim.api.nvim_create_autocmd("InsertEnter", {
  group = group,
  callback = function(args)
    if not enabled or not should_manage_buffer(args.buf) then
      return
    end
    local buf = args.buf
    if vim.b[buf].rime_was_chinese then
      set_ascii_mode(false)
    end
  end,
  desc = "Restore Rime Chinese mode on InsertEnter if previously Chinese",
})

-- 离开命令行（例如搜索 /中文 之后），切回 ASCII 模式
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = group,
  callback = function()
    if not enabled then
      return
    end
    get_ascii_mode(function(is_ascii)
      if not is_ascii then
        set_ascii_mode(true)
      end
    end)
  end,
  desc = "Switch to Rime ASCII mode on CmdlineLeave",
})

-- 用户命令：手动开关自动切换
vim.api.nvim_create_user_command("RimeToggle", function()
  enabled = not enabled
  vim.notify("Rime auto-switch " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO)
end, { desc = "Toggle Rime auto ASCII mode switch" })

return {}
