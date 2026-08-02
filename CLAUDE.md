# Arch Post-Install → Omarchy 迁移中

个人桌面环境配置管理项目。**系统已从 Arch+River 迁移到 Omarchy (Arch+Hyprland)**，
仓库正处于分层重构中：Omarchy 拥有的配置不入库，仓库只管"Omarchy 留给用户的口子"
和"与 Omarchy 无关的个人配置"。

## 项目结构

```
├── dotfiles/          # 配置文件，通过 stow -t ~ dotfiles 部署
│   ├── .config/
│   │   ├── nvim/      # Neovim（Lazy.nvim，插件一文件一个；theme.lua symlink 归 Omarchy 管，不入库）
│   │   ├── fcitx5/    # 输入法
│   │   ├── fontconfig/# 全局中文字体（更纱黑体回退）
│   │   ├── herdr/     # Herdr 布局/agent/会话
│   │   ├── btop/ eza/ mise/ uv/ zsh/ qutebrowser/ swappy/ ...
│   │   └── environment.d/  # uwsm 会话环境变量（与 Omarchy 合并中）
│   └── .local/share/  # fcitx5/rime 自定义、qutebrowser userscripts
├── bin/               # 自定义脚本（35 个），部署到 ~/.local/bin
├── applactions/       # 个人 .desktop 文件和图标（linuxqq/obsidian/wechat）
├── install/           # 部署脚本（dotfile-manager / bin-manager / desktop-manager 等）
├── plymouth/          # 启动画面（待决策：是否改用 omarchy plymouth）
└── install-root.sh    # 旧系统参考，Omarchy 下大部分废弃
```

## 约定

- dotfiles 通过 `install/dotfile-manager install` 部署
- bin 脚本通过 `install/bin-manager install` 部署到 `~/.local/bin`
- desktop 文件通过 `install/desktop-manager install` 部署
- 运行时生成的文件已 gitignore；rime 的 *.userdb 不入库
- `.example` 后缀是模板，不被 stow 部署
- Neovim 快捷键统一在 `keymaps.lua`，插件配置各自独立文件
- 提交信息使用 Conventional Commits 英文格式
- **Omarchy 拥有的配置不入库**：waybar/alacritty/mako/walker/hyprlock/starship 主题部分、
  `~/.local/share/omarchy/`（只读，禁改）
- **Omarchy 用户口子入库**（待迁移）：`~/.config/hypr/{monitors,input,bindings,looknfeel,autostart}.conf`、
  `~/.config/omarchy/hooks/`、自定义主题（须真实目录，stow 部署需 --no-folding）
- `omarchy update` 的 migration 会写 `~/.config`：update 后检查 git status；
  被 `omarchy refresh` 重置后重新 `dotfile-manager install` 恢复

## bin/ 脚本命名规范

脚本按前缀分组，部署到 `~/.local/bin`，互相可直接 `source` 或调用。

| 前缀 | 用途 | 示例 |
|------|------|------|
| `record-audio-*` | RNNoise 麦克风降噪守护进程 | `record-audio-daemon`, `record-audio-enable` |
| `microphone-core` | 麦克风共享逻辑库 | 被 record-audio-* source |
| `waybar-status-*` / `waybar-event-*` | Waybar 模块（降噪状态） | `waybar-status-microphone` |
| `screenrecord-overlay-*` | 录屏叠加层（待适配 Hyprland） | `screenrecord-overlay-keys`, `-captions`, `-title`, `-camera` |
| `screenrecord-core` | 录屏共享库（bilive 依赖） | 不直接运行 |
| `bilive-*` | B站直播推流（待 Hyprland 验证） | `bilive-toggle-full` |
| `screenshot-colorpicker` | 取色器（hyprpicker） | |
| `package-backup` | 包列表备份（待决策是否保留） | |
| `i18n-*` | 国际化 | `i18n-core`（加载器），`i18n-zh-cn`, `i18n-en-us` |
| `ccm` / `cxm` | Claude/Codex API 配置管理 | |
| `askpass` | sudo 图形密码框（**待从 wofi 迁移到 walker**） | |
| `memo` / `corral-toggle` | 个人工具 | |

关键模式：
- `i18n-core` 提供 `msg()` 函数和自动语言检测，脚本中 `source i18n-core` 即可使用
- `*-core` 后缀的脚本是共享库，不直接运行，被同组脚本 source

## 待办（Omarchy 迁移）

- [ ] `screenrecord-overlay-keys/captions` 适配 Hyprland 后绑 `SUPER ALT C/K`（摄像头叠加用 Omarchy `--with-webcam` 替代）
- [ ] `askpass` 从 wofi 迁移到 walker
- [ ] `bilive-*` 在 Hyprland 下验证后绑 `SUPER SHIFT G`（现为 Signal）
- [ ] 待入库：`~/.config/hypr/`（含 Caps↔ESC 对调、两批迁移快捷键）、`satty-cjk` 包装脚本、
      `~/.config/environment.d/screenshot.conf`、`~/.config/fontconfig/fonts.conf`
- [ ] `environment.d/` 与 Omarchy 的 fcitx.conf 合并（阶段 4）
- [ ] `starship.toml`/`uwsm`/`xdg-desktop-portal` 与 Omarchy 现状对比（阶段 4）
- [ ] `package-backup` 保留与否、`plymouth/` 用 Omarchy 主题机制与否（待用户决策）
- [ ] README 全面重写为 Omarchy 版（阶段 6）
