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
    └── .zshrc
```

## 第一次安装

需要系统里已有 `git` 和 `curl`。

先安装官方版 mise。这个版本以后可以用 `mise self-update` 更新自己：

```bash
curl https://mise.run | sh
```

然后下载本仓库：

```bash
git clone https://github.com/xifan2333/arch-post-install.git ~/Code/arch-post-install
cd ~/Code/arch-post-install
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
- `yay`：安装 AUR 软件；
- `unzip`：解压像素字体安装包；
- 当前机器上显式安装的 AUR/外来包，完整清单见下文。

另外会通过 mise 安装 `gh` 等命令行工具（清单见 `~/.config/mise/config.toml`），并把 Rime 自动部署 pacman 钩子声明为 `[bootstrap.files]`，随 bootstrap 自动收敛到 `/etc/pacman.d/hooks`。

mise 本身不能直接安装 AUR 包，所以最后会调用 yay。已经安装的包会直接跳过，不会每次重新下载。

这条命令可以反复运行。已经设置好的内容会跳过，只处理缺少或发生变化的部分，不会每次都从头重装。技术文档里常说的“幂等”，指的就是这个意思。

### 遇到同名文件怎么办

如果用户目录里已经有同名的普通文件，mise 默认会停下来，不会直接覆盖。

先比较并备份原文件。确定要以仓库版本为准后，才使用：

```bash
mise bootstrap --force-dotfiles --yes
```

`--force-dotfiles` 会替换冲突文件，不要在没检查的情况下随便加。

### 权限与鉴权

- 有可见终端时使用普通 `sudo`，由用户在终端输入密码；
- 图形后台任务或 Agent 请求提权时使用 `pkexec`，由轻量鉴权代理 `polkit-gnome` 弹出密码窗口。

## 平时怎么用

下面的命令默认在仓库目录中运行：

```bash
cd ~/Code/arch-post-install
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
mise -C ~/Code/arch-post-install bootstrap --yes
```

## 蓝牙和 Wi-Fi 命令

`custom-bluetooth` 和 `custom-wifi` 不带参数时打开菜单；显式子命令可用于脚本，只有 `menu` 会弹出菜单和桌面通知。

| 操作 | 蓝牙 | Wi-Fi |
| --- | --- | --- |
| 帮助 | `custom-bluetooth --help` | `custom-wifi --help` |
| 只读查询 | `custom-bluetooth status` / `custom-bluetooth list` | `custom-wifi status` / `custom-wifi list` |
| 连接 | `custom-bluetooth connect <MAC或名称>` | `custom-wifi connect <SSID>` |
| 断开 | `custom-bluetooth disconnect [MAC或名称]` | `custom-wifi disconnect` |
| 切换 | `custom-bluetooth toggle` 切换适配器电源 | `custom-wifi toggle` 断开当前连接或连接信号最强的已保存/开放网络 |
| 菜单 | `custom-bluetooth menu` | `custom-wifi menu` |

重复连接已连接的目标不会断开它。蓝牙省略断开目标时断开当前适配器的已连接设备；名称重复时使用 MAC。脚本默认使用查询到的第一个适配器/无线设备。

Wi-Fi 已保存网络和开放网络可直接连接；新加密网络用菜单输入口令，或通过 `custom-wifi connect <SSID> --passphrase-stdin` 从标准输入读取一行口令。显式命令缺少口令、目标或依赖时会报错，不会自动打开菜单。失败不会自动删除保存的凭据。口令经正确引用传给 `iwctl --dont-ask --passphrase`，该子进程的参数仍含口令。

蓝牙菜单在选择扫描或要连接的设备后开启适配器，需要配对时启用配对；取消菜单不改变适配器电源。点击设备切换连接；手机/电脑配对后不强制连接音频服务。CLI 的 `connect` 只请求连接，配对在菜单中完成；设备不支持连接时返回失败。

`list` 输出 TSV，`status` 输出键值文本，连接/断开结果使用固定的英文状态标识。名称中的反斜杠、制表符、换行符和回车分别编码为 `\\`、`\t`、`\n`、`\r`。诊断写入 stderr；退出码 `0` 表示成功或菜单取消，`1` 表示操作失败，`2` 表示参数错误，`127` 表示缺少依赖。

## 桌面命令与状态

20 个桌面工具已全部统一为 `custom-<domain>` 命令，旧命令和桌面启动器名称已移除。缺依赖、读取失败或服务失败会直接报错。标题和字体各自只有一个 state 路径，字体通过 bootstrap 显式初始化并保留现有选择；录屏由固定的 systemd 用户服务管理。

命令用法、状态迁移、图片流和录屏错误排查见 [桌面 CLI 说明](.agents/skills/arch-guide/references/custom-cli.md)。

## 代码规范与检查

项目按文件类型使用对应工具：Python 用 Ruff，JavaScript 用 Oxlint，Bash 用 ShellCheck，Lua 和 Zsh 做语法检查，TOML 用 Taplo，JSON/JSONC/YAML 用 Prettier。版本统一固定在根目录的 `mise.toml`。

首次使用先安装工具：

```bash
mise install
```

检查所有 Git 已跟踪文件（不会改文件）：

```bash
mise run lint
```

自动格式化支持的文件：

```bash
mise run format
```

日常修改先预览检查范围，再执行增量检查：

```bash
mise run check:plan
mise run check:changed
```

`check:changed` 是 `check` 的别名，由 hk 原生选择暂存、未暂存和未跟踪文件。`mise run fix` 修复修改过的文件；`mise run format` 修复整个仓库。

任务参数可直接传给 hk，例如 `mise run check:plan --all` 查看全量匹配范围，或 `mise run check dotfiles/.local/bin/custom-capture` 检查指定文件。所有脚本和配置文件均完全由官方原生 linter 原生识别，零非标自定义检查。

GitHub Actions 对 push 和 pull request 执行 `mise run lint`。开发工具统一在根目录 `mise.toml` 声明，CI 由 `mise-action` 自动安装。运行行为按变更领域验证。

## 配置文件是怎么连接的

mise 会为仓库中的文件创建软链接。例如：

```text
~/.zshrc -> ~/Code/arch-post-install/dotfiles/.zshrc
```

所以修改 `~/.zshrc`，实际改到的就是仓库里的文件，可以直接用 Git 查看和提交。

mise 只碰本仓库列出的文件。共享目录中由其他程序创建的内容不会被删除，例如：

- `~/.local/bin/mise`
- `~/.local/bin/codex`
- Neovim 自己生成的状态文件

`*.tera` 由 mise 渲染为配置文件，源文件不建立软链接。修改 state 路径后需要重新应用 dotfiles。

`*.example` 只作为仓库模板，不会软链到用户目录；首次 bootstrap 时若真实配置还不存在，会复制到对应路径（之后不再覆盖）。

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

## 快捷键与会话管理

桌面环境基于 River 0.4 与自研的 xrwm 窗口管理器，开机由 systemd 会话结合 `uwsm` 直接拉起，无需显示管理器（DM）或登录 Shell。

| 快捷键                  | 动作                                                   |
| ----------------------- | ------------------------------------------------------ |
| `Super+Return`          | 打开超轻量 Wayland 终端 (`ftty`)                       |
| `Super+Space` / `Super+D` | 应用启动器 (`fuzzel`)                                  |
| `Super+Shift+E`         | 终端文件管理器 (`yazi`)                                |
| `Super+B`               | 打开网页浏览器 (`chromium`)                            |
| `Super+N` / `Super+Ctrl+W` | Wi-Fi 与网络控制菜单 (`arch-net-menu`)                |
| `Super+Escape`          | 屏幕锁屏 (`hyprlock`)                                  |
| `Super+Q` / `Super+W`   | 关闭当前窗口                                           |
| `Super+F` / `F11`       | 全屏切换                                               |
| `Super+P`               | 浮动窗口切换                                           |
| `Super+H/J/K/L`         | 焦点移动 (Vim 风格导航)                                |
| `Super+Shift+H/J/K/L`   | 窗口交换与移动                                         |
| `Super+1..9`            | 工作区切换 (Tag 1-9)                                   |
| `Super+Shift+1..9`      | 移动窗口至指定工作区                                   |
| `Super+Shift+S`         | 区域截图并存入剪贴板 (`grim + slurp`)                  |
| `Print`                 | 全屏截图并存入剪贴板                                   |
| `XF86AudioRaise/Lower`  | 扬声器音量增减 (`PipeWire wpctl`)                      |
| `XF86AudioMute`         | 扬声器静音切换                                         |
| `XF86AudioMicMute`      | 麦克风静音切换                                         |
| `XF86MonBrightnessUp/Dn`| 屏幕亮度调节 (`brightnessctl`)                         |
| `XF86AudioPlay/Next/Prev` | 媒体播放控制 (`playerctl`)                           |

## 仓库包含什么

| 类别     | 说明                                                                   |
| -------- | ---------------------------------------------------------------------- |
| 窗口管理 | River 0.4 与 xrwm 模块化规则、快捷键与状态栏配置                        |
| 终端     | ftty 超轻量 Wayland 终端与 Kitty 图像协议支持                          |
| 启动与锁屏 | systemd 原生无缝直启服务与 hyprlock 生物识别锁屏                     |
| Neovim   | LazyVim、补全、格式化和动态主题热加载 (`theme-hotreload`)               |
| Zsh      | 补全、插件、快捷键、别名和工具初始化                                   |
| 输入法   | Fcitx5 与万象小鹤双拼 (`rime-wanxiang-flypy`) 离线主题联动              |
| 状态栏   | Waybar 极简暗黑与语义主题状态栏                                        |
| 网络管理 | iwd 与 fuzzel 驱动的纯粹无依赖 Wi-Fi 控制套件 (`arch-net-*`)            |
| 主题引擎 | 22 款语义化配色方案联动全桌面 (`arch-theme-set`)                       |
| 模拟器   | RetroArch 配置与全局着色器预设                                         |
| 翻译     | 翻译脚本和 qutebrowser userscript                                      |
| 工具     | Node、Python、uv、pi 等命令行工具                                      |
