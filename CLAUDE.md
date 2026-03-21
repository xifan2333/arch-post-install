# Arch Post-Install

Arch Linux 个人桌面环境配置管理项目。

## 项目结构

```
├── dotfiles/          # 配置文件，通过 stow -t ~ dotfiles 部署
│   ├── .config/
│   │   ├── nvim/      # Neovim（Lazy.nvim，插件一文件一个）
│   │   ├── river/     # River WM
│   │   ├── themes/    # 主题集（symlink 切换）
│   │   ├── dunst/     # 通知
│   │   ├── fcitx5/    # 输入法
│   │   ├── waybar/    # 状态栏
│   │   └── ...
│   └── .local/
├── bin/               # 自定义脚本，部署到 ~/.local/bin
├── applactions/       # .desktop 文件和图标，部署到 ~/.local/share/applications
├── install/           # 部署脚本
│   ├── dotfile-manager   # stow 管理 dotfiles
│   ├── bin-manager       # symlink 管理 bin/
│   ├── desktop-manager   # 管理 .desktop 文件
│   ├── setup-mime        # MIME 类型配置
│   └── setup-noise-suppression  # 降噪配置
├── plymouth/          # 启动画面
├── docs/              # 文档
└── install-root.sh    # root 级系统配置
```

## 约定

- dotfiles 通过 `install/dotfile-manager install` 部署
- bin 脚本通过 `install/bin-manager install` 部署到 `~/.local/bin`
- desktop 文件通过 `install/desktop-manager install` 部署
- 运行时生成的文件（主题 symlink 产物等）已 gitignore
- `.example` 后缀是模板，不被 stow 部署
- Neovim 快捷键统一在 `keymaps.lua`，插件配置各自独立文件
- 提交信息使用 Conventional Commits 英文格式
- bin/ 下脚本按功能前缀分组：theme-*, font-*, river-*, screenshot-*, ui-* 等

## bin/ 脚本命名规范

脚本按前缀分组，部署到 `~/.local/bin`，互相可直接 `source` 或调用。

| 前缀 | 用途 | 示例 |
|------|------|------|
| `ui-*` | GUI 交互入口，通过 `ui-wofi` 提供 wofi 菜单 | `ui-theme`, `ui-screenshot` |
| `theme-sync-*` | 将当前主题同步到各应用 | `theme-sync-dunst`, `theme-sync-terminal` |
| `font-sync-*` | 将当前字体同步到各应用 | `font-sync-alacritty`, `font-sync-waybar` |
| `font-get-*` / `font-set` | 字体读取/设置 | `font-get-current`, `font-set` |
| `river-*` | River WM 操作 | `river-reload`, `river-scratchpad-toggle` |
| `screenshot-*` | 截图功能 | `screenshot-save-area`, `screenshot-colorpicker` |
| `screenrecord-*` | 录屏功能 | `screenrecord-start-full`, `screenrecord-stop` |
| `waybar-status-*` | Waybar 状态模块（输出 JSON） | `waybar-status-screenrecord` |
| `waybar-event-*` | Waybar 点击事件处理 | `waybar-event-screenrecord` |
| `package-*` | 包管理操作 | `package-install`, `package-backup` |
| `webapp-*` | Web 应用管理 | `webapp-install-desktop`, `webapp-launch` |
| `tui-*` | TUI 应用管理 | `tui-install-desktop`, `tui-list-desktop` |
| `component-*` | 可复用的 UI 组件 | `component-show-logo`, `component-show-done` |
| `i18n-*` | 国际化 | `i18n-core`（加载器），`i18n-zh-cn`, `i18n-en-us` |
| `*-core` | 共享逻辑库，被同组脚本 source | `screenrecord-core`, `screenshot-core` |

关键模式：
- `ui-wofi` 是所有 GUI 菜单的统一入口，封装了 wofi 调用和主题加载
- `i18n-core` 提供 `msg()` 函数和自动语言检测，脚本中 `source i18n-core` 即可使用
- `terminal-launch` 用于在浮动窗口中运行命令，class 格式为 `floating-terminal-{脚本名}`，River 通过 glob `floating-terminal-*` 匹配为浮动窗口
- `*-core` 后缀的脚本是共享库，不直接运行，被同组脚本 source
