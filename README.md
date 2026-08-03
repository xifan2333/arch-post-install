# arch-post-install

个人 Arch Linux 安装后配置，基于 [GNU Stow](https://www.gnu.org/software/stow/) 管理 home 目录下的 dotfiles。

## 结构

```
arch-post-install/
├── dotfiles/          # stow 包，映射到 ~/ 的配置文件
│   ├── .config/       # hypr, nvim, zsh, tmux/kitty, fcitx5, ...
│   ├── .local/        # 自定义脚本、desktop 文件
│   ├── .zshrc
│   └── .tmux.conf
└── install/
    └── dotfile-manager  # 一键安装/卸载脚本
```

## 安装

依赖：[stow](https://www.gnu.org/software/stow/)

```bash
git clone git@github.com:<user>/arch-post-install.git
cd arch-post-install
./install/dotfile-manager install
```

脚本会将 `dotfiles/` 下的文件通过符号链接映射到 `$HOME`。如果目标位置已有同名文件，`stow --adopt` 会先把已有内容拉进仓库再替换为符号链接，不会丢数据。

## 卸载

```bash
./install/dotfile-manager uninstall
```

移除所有 stow 创建的符号链接，恢复干净状态。

## 主要内容

| 类别 | 说明 |
|------|------|
| Hyprland | 窗口管理器全套：按键绑定、外观、显示器、空闲锁屏等 |
| Neovim | 基于 LazyVim，带 blink.cmp 补全、conform 格式化、自定义主题热加载 |
| Zsh | 模块化配置：选项、补全、插件、按键绑定、别名、工具函数 |
| Tmux | C-Space 前缀、vi 模式、分屏/窗口/会话快捷键、状态栏主题 |
| 输入法 | Fcitx5 + Rime，中英文配置 |
| 终端 | Kitty 配置 |
| 主题 | Omarchy 主题系统 hook，切换主题时同步 fcitx5/herdr 配色 |
| 录制 | 音频录制、屏幕录制叠加层（摄像头/按键/标题） |
| 翻译 | i18n 脚本、qutebrowser 翻译 userscript |
| 其他 | Git、Starship 提示符、PipeWire 降噪、Mise 版本管理 |

## 日常使用

- 修改配置后直接 `git add` + `commit` 即可，stow 符号链接指向仓库实际文件
- `dotfile-manager install` 可重复执行（幂等）
