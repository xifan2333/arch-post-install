# Arch Linux Post-Install Setup

一键配置 Arch Linux 系统，提供开箱即用的中文环境和 Wayland 桌面。

## 特性

- **一键安装**: 运行单个脚本完成所有配置
- **中文优化**: 完整的中文本地化和输入法支持
- **智能输入**: fcitx5 + 雾凇拼音 + AI 语言模型
- **现代桌面**: River WM + Waybar + Foot
- **美观主题**: 深色主题和中文字体
- **模块化**: 清晰的脚本结构，易于定制

## 安装内容

### 系统级配置
- ✓ Locale 和时区设置
- ✓ 中文字体（思源、Noto CJK、文泉驿等）
- ✓ Pacman 镜像源和 archlinuxcn 仓库
- ✓ AUR helper (yay)

### 输入法（重点）
- ✓ fcitx5 完整套件
- ✓ 雾凇拼音词库
- ✓ 万象语言模型（上下文联想）
- ✓ 优化配置（逗号句号翻页、9 个候选词）

### Wayland 环境
- ✓ River compositor
- ✓ Waybar 状态栏
- ✓ Foot 终端
- ✓ 相关工具（wl-clipboard, grim, slurp 等）

### 桌面工具
- ✓ 启动器：wofi
- ✓ 锁屏：swaylock
- ✓ 通知：dunst
- ✓ 文件管理器：thunar
- ✓ 截图工具：grim + slurp

### 应用程序
- ✓ Firefox（含中文语言包）
- ✓ Visual Studio Code
- ✓ 媒体播放器（mpv, vlc）
- ✓ PDF 阅读器（zathura）

## 快速开始

### 两阶段安装

#### 阶段 1：arch-chroot 中运行（以 root 身份）

在 archinstall 或手动安装后，挂载系统并进入 chroot：

```bash
# 挂载分区（示例）
mount /dev/sdX2 /mnt
arch-chroot /mnt

# 下载脚本
curl -O https://raw.githubusercontent.com/xifan2333/arch-post-install/main/install-chroot.sh
chmod +x install-chroot.sh

# 运行 Stage 1
./install-chroot.sh

# 退出 chroot 并重启
exit
umount -R /mnt
reboot
```

**Stage 1 做了什么：**
- 安装 NetworkManager（确保重启后有网络）
- 配置 pacman（multilib, archlinuxcn）
- 安装 base-devel 和 git
- 配置 locale 和时区

#### 阶段 2：系统启动后运行（以普通用户身份）

```bash
# 登录普通用户后
git clone https://github.com/xifan2333/arch-post-install.git
cd arch-post-install

# 运行 Stage 2
./install-user.sh

# 完成后注销并重新登录
```

**Stage 2 做了什么：**
- 安装 yay
- 安装中文字体
- 安装 fcitx5 + 雾凇拼音
- 安装 River + Waybar + Foot
- 安装桌面工具和应用

### 安装后配置

#### 1. 启用 fcitx5 输入法
```bash
# 注销并重新登录后，fcitx5 会自动启动
# 如果没有自动启动，运行：
fcitx5 &

# 打开配置工具
fcitx5-configtool
```

在配置工具中：
1. 点击"添加输入法"
2. 取消勾选"仅显示当前语言"
3. 搜索"rime"并添加
4. 将 Rime 移到输入法列表顶部

#### 2. 测试输入法
- 按 `Ctrl+Space` 切换输入法
- 输入拼音测试（应该能看到智能候选词）
- 使用逗号/句号翻页
- 长句输入测试雾凇拼音的智能联想

#### 3. River WM 使用
River 的默认快捷键：
- `Super+Return`: 打开终端
- `Super+D`: 启动器
- `Super+Q`: 关闭窗口
- `Super+Shift+E`: 退出 River

## 项目结构

```
arch-post-install/
├── install.sh                 # 主安装脚本
├── scripts/
│   ├── helpers/              # 辅助函数（日志、输出、错误处理）
│   ├── preflight/            # 预检查（环境、网络、pacman）
│   ├── packaging/            # 软件包安装
│   ├── config/               # 系统配置
│   └── post-install/         # 收尾工作
├── dotfiles/                 # 配置文件（待实现）
├── docs/                     # 文档
└── README.md
```

## 自定义

### 修改软件包列表
编辑对应的脚本文件：
- `scripts/packaging/base.sh` - 基础软件
- `scripts/packaging/apps.sh` - 应用程序
- 等

### 跳过某些步骤
编辑 `install.sh`，注释掉不需要的阶段。

### 单独运行某个模块
```bash
source scripts/helpers/all.sh
bash scripts/packaging/fcitx5.sh
```

## 常见问题

### 输入法打字太快漏字
确保安装了 `fcitx5-gtk` 和 `fcitx5-qt`，并正确设置了环境变量（脚本会自动处理）。

### 雾凇拼音 AUR 安装失败
脚本会自动回退到手动安装方式（git clone），不影响使用。

### River 无法启动
检查是否安装了显示管理器（如 ly, sddm），或在 `.xinitrc` 中添加 `exec river`。

## 参考资料

本项目参考了：
- [unixchad/dotfiles](https://github.com/gnuunixchad/dotfiles) - dotfiles 管理
- [omarchy](https://github.com/basecamp/omarchy) - 安装脚本结构
- [rime-ice](https://github.com/iDvel/rime-ice) - 雾凇拼音
- [Andy Stewart 的 fcitx5 配置指南](https://manateelazycat.github.io/)

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

##