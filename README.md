# arch-post-install

个人 Arch Linux 安装后配置，使用 [mise bootstrap](https://mise.jdx.dev/bootstrap.html) 声明式管理 dotfiles、开发工具和安装后的收尾任务。

## 结构

```text
arch-post-install/
├── mise.toml                         # bootstrap、dotfiles 映射和 tasks
├── mise/
│   └── config.toml                   # 指向全局 tools 配置的项目入口
└── dotfiles/                         # 映射到 $HOME 的配置源
    ├── .config/
    ├── .local/
    ├── .zshrc
    └── .tmux.conf
```

## 首次安装

依赖：`git`、`curl`。

先安装支持自更新的官方 mise：

```bash
curl https://mise.run | sh
```

然后克隆仓库并执行 bootstrap：

```bash
git clone https://github.com/xifan2333/arch-post-install.git ~/code/arch-post-install
cd ~/code/arch-post-install
~/.local/bin/mise trust
~/.local/bin/mise bootstrap --dry-run
~/.local/bin/mise bootstrap --yes
```

bootstrap 会依次应用 dotfiles、安装 `[tools]` 中缺少的工具，并运行幂等的收尾任务。

已有同名真文件时，mise 默认拒绝覆盖。确认仓库内容应当成为配置源后，可显式使用：

```bash
mise bootstrap --force-dotfiles --yes
```

## 日常使用

命令需要在仓库目录中运行，也可以使用 `mise -C ~/code/arch-post-install ...`。

```bash
# 检查整体状态
mise bootstrap status
mise bootstrap status --missing

# 预览并同步全部配置
mise bootstrap --dry-run
mise bootstrap --yes

# 只同步 dotfiles
mise bootstrap --only dotfiles --yes

# 只安装或更新缺少的开发工具
mise bootstrap --only tools --yes

# 更新 mise 自身
mise self-update
```

修改 `$HOME` 下的受管配置会直接修改仓库源文件，因为目标是符号链接。

## Dotfiles 行为

共享目录使用 `symlink-each`：mise 只管理仓库中的文件，不会删除目录里由其他程序创建的文件。例如 `~/.local/bin/mise`、`~/.local/bin/codex` 和 Neovim 的本地状态会保留。

以下文件被有意排除：

- `~/.config/hypr/monitors.conf`：本机显示器配置
- `*.example`：示例配置

卸载前建议先预览：

```bash
mise bootstrap dotfiles unapply --dry-run
mise bootstrap dotfiles unapply --yes
```

`unapply` 只移除 mise 记录的受管链接，并保留共享目录中的非受管文件。

## 专项任务

WPS 多组件模式逻辑直接定义在 `mise.toml` 中：

```bash
mise run wps
```

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
| 工具 | mise 管理 Node、Python、uv、pi 等开发工具 |
