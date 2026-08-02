local opt = vim.opt

-- OSC52/tmux clipboard: yanks broadcast to attached clients, paste prefers local Wayland clipboard
require('config.remote_clipboard').setup()

opt.number = true
opt.relativenumber = false
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 200
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.termguicolors = true
opt.cursorline = true
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.confirm = true
opt.undofile = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
