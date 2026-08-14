# arch-post-install

我的 Arch Linux 配置仓库。它用 [mise bootstrap](https://mise.jdx.dev/bootstrap.html) 完成这些事情：

1. 把仓库里的配置文件链接到用户目录；
2. 安装配置依赖的系统软件，例如麦克风降噪插件；
3. 安装 Node、Python、uv、pi 等命令行工具；
4. 做少量安装后的处理，例如设置 WPS 模式和连接 Neovim 主题。

## 目录结构

```text
arch-post-install/
├── mise.toml                         # 安装步骤和配置文件映射
├── mise/
│   └── config.toml                   # Node、Python 等工具的版本配置
└── dotfiles/                         # 实际的配置文件
    ├── .config/
    ├── .local/
    ├── .zshrc
    └── .tmux.conf
```

## 第一次安装

需要系统里已有 `git` 和 `curl`。

先安装官方版 mise。这个版本以后可以用 `mise self-update` 更新自己：

```bash
curl https://mise.run | sh
```

然后下载本仓库：

```bash
git clone https://github.com/xifan2333/arch-post-install.git ~/code/arch-post-install
cd ~/code/arch-post-install
~/.local/bin/mise trust
```

先看看 mise 准备改什么：

```bash
~/.local/bin/mise bootstrap --dry-run
```

确认没有问题后再真正执行：

```bash
~/.local/bin/mise bootstrap --yes
```

执行后，mise 会安装缺少的系统软件、连接配置文件、安装缺少的命令行工具，然后运行最后的设置步骤。

默认还会安装这些额外内容：

- `noise-suppression-for-voice`：麦克风降噪插件；
- `zenity`：sudo 图形密码窗口；
- `yay`：安装 AUR 软件；
- `unzip`：解压像素字体安装包；
- 当前机器上显式安装的 AUR/外来包，完整清单见下文。

另外会通过 mise 安装 `gh` 等命令行工具（清单见 `~/.config/mise/config.toml`），并把 QQ/微信的 Wayland 输入法 pacman 钩子声明为 `[bootstrap.files]`，随 bootstrap 自动收敛到 `/etc/pacman.d/hooks`。

mise 本身不能直接安装 AUR 包，所以最后会调用 yay。已经安装的包会直接跳过，不会每次重新下载。

这条命令可以反复运行。已经设置好的内容会跳过，只处理缺少或发生变化的部分，不会每次都从头重装。技术文档里常说的“幂等”，指的就是这个意思。

### 遇到同名文件怎么办

如果用户目录里已经有同名的普通文件，mise 默认会停下来，不会直接覆盖。

先比较并备份原文件。确定要以仓库版本为准后，才使用：

```bash
mise bootstrap --force-dotfiles --yes
```

`--force-dotfiles` 会替换冲突文件，不要在没检查的情况下随便加。

## 平时怎么用

下面的命令默认在仓库目录中运行：

```bash
cd ~/code/arch-post-install
```

查看当前配置是否完整：

```bash
mise bootstrap status
```

预览同步结果，不实际修改：

```bash
mise bootstrap --dry-run
```

同步全部内容：

```bash
mise bootstrap --yes
```

只同步配置文件：

```bash
mise bootstrap --only dotfiles --yes
```

只检查并安装工具：

```bash
mise bootstrap --only tools --yes
```

更新 mise 自己：

```bash
mise self-update
```

不想先 `cd` 时，可以这样运行：

```bash
mise -C ~/code/arch-post-install bootstrap --yes
```

## 配置文件是怎么连接的

mise 会为仓库中的文件创建软链接。例如：

```text
~/.zshrc -> ~/code/arch-post-install/dotfiles/.zshrc
```

所以修改 `~/.zshrc`，实际改到的就是仓库里的文件，可以直接用 Git 查看和提交。

mise 只碰本仓库列出的文件。共享目录中由其他程序创建的内容不会被删除，例如：

- `~/.local/bin/mise`
- `~/.local/bin/codex`
- Neovim 自己生成的状态文件

以下内容特意没有交给 mise 管理：

- `~/.config/hypr/monitors.conf`：每台电脑的显示器配置可能不同；
- `*.example`：只供参考的示例文件。

## 移除配置链接

先预览会移除哪些链接：

```bash
mise bootstrap dotfiles unapply --dry-run
```

确认后执行：

```bash
mise bootstrap dotfiles unapply --yes
```

它只删除由 mise 创建的链接，不会删除共享目录里的其他文件。

## AUR 和外来软件包

默认 bootstrap 会检查并补装以下软件包：

```text
dmnotifier-bin
fcitx5-vinput-bin
flac1.3
herdr-corral-bin
karing-bin
linuxqq-appimage
listen1
ttf-wps-fonts
unibarrage-bin
wechat-appimage
wps-office-365-edu
wps-office-365-edu-fonts
```

可以单独执行这一步：

```bash
mise run aur
```

这个任务只确认这些软件包已经安装，不会自动升级现有版本。需要更新时仍然使用 `yay -Syu`。

## WPS 多组件模式

`mise bootstrap` 每次都会运行这一步（bootstrap 任务依赖 `wps`），也可以单独执行：

```bash
mise run wps
```

它会把 WPS 的两个相关设置改成 `prome_independ`。重复执行也没关系：已有设置会更新，缺少的设置会补上，不会重复添加。

## 像素字体

为 pi-undefined-video 的字幕渲染安装像素字体（Fusion Pixel 12px、Uranus Pixel、BoutiqueBitmap7x7）。字体只服务于按需渲染，不随 bootstrap 自动安装，需要时执行：

```bash
mise run fonts
```

每次运行都会下载对应 GitHub 项目的最新 release 并刷新字体缓存。脚本依赖 `gh` 和 `unzip`，两者分别由 `~/.config/mise/config.toml` 的 `[tools]` 和 `[bootstrap.packages]` 提供。

## 录屏与直播

本地录屏和直播通过 `capture-router` 严格互斥，快捷键、Omarchy Capture 菜单和 Waybar 都走同一个运行时锁。正在录屏时启动直播（或反过来）只会提示先停止当前任务，不会自动切换。

常用命令：

```bash
capture-router menu                              # 统一采集菜单
capture-router status                            # idle / recording / livestream
capture-router livestream start|stop|toggle      # 直播
capture-router livestream status                 # 各平台 RTMP 连接状态与码率
capture-router recording start|stop|toggle       # 本地录屏
capture-router overlay camera|captions|keys|title|edit
capture-router audio enable|disable|status       # 混音 + 人声避让
```

每个平台在 `~/.config/livestream/platforms.conf` 中独立设置码率，也可以通过 `Super + Shift + R` 打开图形配置：

```ini
[Bilibili]
server = live-push.example.com/live
key = STREAM_KEY
video_bitrate = 6000
audio_bitrate = 192
```

`livestream-service` 在 Session D-Bus 上提供 `GetStatus`、`Stop` 和 `StatusChanged`，所有平台状态只保存在服务内存中；运行时只落一个权限为 `600` 的脱敏日志。直播只有在对应 `gpu-screen-recorder` 进程持续运行、持有 `ESTABLISHED` TCP 连接，并且 RTMP 服务端已经确认至少 64 KiB 的输出数据后，才会标记为 `RTMP sending`。这能确认本机正在向平台 ingest 发送数据；平台是否已正式开播、是否对观众可见，仍以平台控制台或平台 API 为准。

适配只使用 Omarchy 的公开命令 `omarchy capture screenrecording`，不会修改 `~/.local/share/omarchy`。Waybar 的 `config.jsonc` 是普通文件，只包含采集状态、工作区覆盖和 Omarchy 当前默认配置三个 include。Omarchy 更新迁移若替换该文件，`post-update.d/waybar-capture.hook` 会从用户层模板恢复它；`style.css` 不会被修改。

## 仓库包含什么

| 类别 | 说明 |
|------|------|
| Hyprland | 按键、外观、显示器、空闲锁屏等配置 |
| Neovim | LazyVim、补全、格式化和主题热加载 |
| Zsh | 补全、插件、快捷键、别名和工具初始化 |
| Tmux | C-Space 前缀、vi 模式、窗口和分屏快捷键 |
| 输入法 | Fcitx5 和 Rime 配置 |
| 终端 | Kitty 配置 |
| 主题 | 切换 Omarchy 主题时同步其他程序的配色 |
| 录制 | 音频录制和屏幕录制叠加层 |
| 模拟器 | RetroArch 配置与全局着色器预设 |
| 翻译 | 翻译脚本和 qutebrowser userscript |
| 工具 | Node、Python、uv、pi 等命令行工具 |
