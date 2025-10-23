# Plymouth 启动画面配置

完整的 Plymouth 启动画面配置，包含主题安装、无缝登录和引导器配置。

## 目录结构

```
plymouth/
├── custom-theme/           # 主题文件
│   ├── *.png              # 主题图片资源
│   ├── custom-theme.plymouth
│   └── custom-theme.script
├── install-all.sh         # 总安装脚本（推荐）
├── install-plymouth.sh    # Plymouth 主题安装
└── install-seamless-login.sh  # 无缝登录配置
```

## 快速开始

### 完整安装（推荐）

```bash
sudo ./plymouth/install-all.sh
```

这将提供交互式菜单，让你选择：
1. Plymouth 主题 + 引导器配置
2. 无缝登录配置
3. 完整安装（推荐）
4. 仅安装 Plymouth 主题

### 分步安装

#### 1. 仅安装 Plymouth 主题

```bash
sudo ./plymouth/install-plymouth.sh
```

功能：
- 安装 Plymouth 包
- 安装自定义主题
- 配置 mkinitcpio hooks
- 自动检测并配置引导器（GRUB/systemd-boot/Limine/UKI）
- 重新生成 initramfs

#### 2. 配置无缝登录

```bash
sudo ./plymouth/install-seamless-login.sh
```

功能：
- 编译并安装 seamless-login 程序
- 自动检测桌面环境（Hyprland/Sway/KDE/GNOME）
- 创建 systemd 自动登录服务
- 配置 Plymouth 延迟退出
- 禁用 getty@tty1

## 主题自定义

### 修改图片

替换 `custom-theme/` 目录中的图片：
- **logo.png** - 启动 logo（建议 200-400px）
- **progress_bar.png** - 进度条（314x6px）
- **progress_box.png** - 进度条背景（314x6px）
- **lock.png** - 锁图标（84x96px）
- **entry.png** - 密码输入框（300x40px）
- **bullet.png** - 密码点（7x7px）

### 修改颜色

编辑 `custom-theme/custom-theme.script`:

```javascript
// 背景渐变色（第 3-4 行）
Window.SetBackgroundTopColor(0.101, 0.105, 0.149);
Window.SetBackgroundBottomColor(0.101, 0.105, 0.149);
```

编辑 `custom-theme/custom-theme.plymouth`:

```ini
# 控制台背景色（第 9 行）
ConsoleLogBackgroundColor=0x1a1b26
```

### 修改动画速度

编辑 `custom-theme/custom-theme.script`:

```javascript
// 进度条配置（第 13-14 行）
global.fake_progress_limit = 0.7;      // 目标进度 (0.0-1.0)
global.fake_progress_duration = 15.0;  // 持续时间（秒）
```

## 使用说明

### 预览主题

```bash
sudo plymouthd --debug
sudo plymouth --show-splash
sleep 5
sudo plymouth quit
```

### 查看可用主题

```bash
plymouth-set-default-theme --list
```

### 切换主题

```bash
sudo plymouth-set-default-theme -R <主题名>
```

### 修改自动登录会话

编辑 systemd 服务：

```bash
sudo systemctl edit seamless-login.service
```

或直接编辑：

```bash
sudo nano /etc/systemd/system/seamless-login.service
```

修改 `ExecStart` 行为你的桌面启动命令。

### 禁用自动登录

```bash
sudo systemctl disable seamless-login.service
sudo systemctl enable getty@tty1.service
```

### 恢复自动登录

```bash
sudo systemctl enable seamless-login.service
sudo systemctl disable getty@tty1.service
```

## 支持的引导器

脚本会自动检测并配置以下引导器：
- **Limine** - 自动添加 `splash quiet` 到 cmdline
- **systemd-boot** - 修改 `/boot/loader/entries/*.conf`
- **GRUB** - 修改 `/etc/default/grub` 并重新生成配置
- **UKI** - 修改 `/etc/cmdline.d/` 或 `/etc/kernel/cmdline`

## 支持的桌面环境

无缝登录脚本会自动检测：
- **Hyprland** (通过 UWSM 或直接启动)
- **Sway**
- **KDE Plasma**
- **GNOME**

如果使用其他桌面环境，需要手动编辑服务文件。

## 安全注意事项

无缝登录会自动登录到桌面，建议：
1. 启用磁盘加密（LUKS）
2. 使用 hyprlock 等锁屏工具
3. 设置屏幕自动锁定

## 故障排除

### Plymouth 不显示

1. 检查主题是否正确安装：
   ```bash
   plymouth-set-default-theme
   ```

2. 检查 mkinitcpio hooks：
   ```bash
   grep HOOKS /etc/mkinitcpio.conf
   ```
   应该包含 `plymouth`

3. 检查内核参数：
   ```bash
   cat /proc/cmdline
   ```
   应该包含 `splash quiet`

4. 重新生成 initramfs：
   ```bash
   sudo mkinitcpio -P
   ```

### 自动登录失败

1. 检查服务状态：
   ```bash
   systemctl status seamless-login.service
   ```

2. 查看日志：
   ```bash
   journalctl -u seamless-login.service -b
   ```

3. 检查 seamless-login 程序：
   ```bash
   ls -l /usr/local/bin/seamless-login
   ```

### 黑屏问题

如果启动后黑屏：
1. 按 `Ctrl+Alt+F2` 切换到 TTY2
2. 登录并检查日志
3. 禁用自动登录：
   ```bash
   sudo systemctl disable seamless-login.service
   sudo systemctl enable getty@tty1.service
   sudo reboot
   ```

## 卸载

### 卸载 Plymouth 主题

```bash
sudo plymouth-set-default-theme -R bgrt  # 切换到默认主题
sudo rm -rf /usr/share/plymouth/themes/custom-theme
```

### 卸载无缝登录

```bash
sudo systemctl disable seamless-login.service
sudo systemctl enable getty@tty1.service
sudo systemctl unmask plymouth-quit-wait.service
sudo rm /etc/systemd/system/seamless-login.service
sudo rm /usr/local/bin/seamless-login
sudo systemctl daemon-reload
```

## 参考

- [Plymouth Arch Wiki](https://wiki.archlinux.org/title/Plymouth)
- [Omarchy 项目](https://github.com/basecamp/omarchy)
