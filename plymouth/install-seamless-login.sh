#!/bin/bash

# 无缝登录配置脚本
# 实现从 Plymouth 到桌面环境的无缝过渡

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 sudo 运行此脚本"
    exit 1
fi

# 获取实际用户名
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo ~$REAL_USER)

log_info "开始配置无缝登录..."

# ==============================================================================
# 1. 编译并安装 seamless-login
# ==============================================================================

if [ ! -x /usr/local/bin/seamless-login ]; then
    log_info "编译 seamless-login 程序..."

    cat <<'CCODE' >/tmp/seamless-login.c
/*
 * Seamless Login - Minimal SDDM-style Plymouth transition
 * Replicates SDDM's VT management for seamless auto-login
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/kd.h>
#include <linux/vt.h>
#include <sys/wait.h>
#include <string.h>

int main(int argc, char *argv[]) {
    int vt_fd;
    int vt_num = 1; // TTY1
    char vt_path[32];

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <session_command>\n", argv[0]);
        return 1;
    }

    // Open the VT (simple approach like SDDM)
    snprintf(vt_path, sizeof(vt_path), "/dev/tty%d", vt_num);
    vt_fd = open(vt_path, O_RDWR);
    if (vt_fd < 0) {
        perror("Failed to open VT");
        return 1;
    }

    // Activate the VT
    if (ioctl(vt_fd, VT_ACTIVATE, vt_num) < 0) {
        perror("VT_ACTIVATE failed");
        close(vt_fd);
        return 1;
    }

    // Wait for VT to be active
    if (ioctl(vt_fd, VT_WAITACTIVE, vt_num) < 0) {
        perror("VT_WAITACTIVE failed");
        close(vt_fd);
        return 1;
    }

    // Critical: Set graphics mode to prevent console text
    if (ioctl(vt_fd, KDSETMODE, KD_GRAPHICS) < 0) {
        perror("KDSETMODE KD_GRAPHICS failed");
        close(vt_fd);
        return 1;
    }

    // Clear VT and close (like SDDM does)
    const char *clear_seq = "\33[H\33[2J";
    if (write(vt_fd, clear_seq, strlen(clear_seq)) < 0) {
        perror("Failed to clear VT");
    }

    close(vt_fd);

    // Set working directory to user's home
    const char *home = getenv("HOME");
    if (home) chdir(home);

    // Now execute the session command
    execvp(argv[1], &argv[1]);
    perror("Failed to exec session");
    return 1;
}
CCODE

    gcc -o /tmp/seamless-login /tmp/seamless-login.c
    mv /tmp/seamless-login /usr/local/bin/seamless-login
    chmod +x /usr/local/bin/seamless-login
    rm /tmp/seamless-login.c

    log_info "seamless-login 已安装到 /usr/local/bin/seamless-login"
else
    log_info "seamless-login 已存在"
fi

# ==============================================================================
# 2. 检测桌面环境
# ==============================================================================

log_info "检测桌面环境..."

# 检测可用的桌面会话
SESSION_COMMAND=""

if command -v uwsm &>/dev/null && [ -f /usr/share/wayland-sessions/river.desktop ]; then
    SESSION_COMMAND="uwsm start -F river"
    log_info "检测到 River (通过 UWSM)"
elif [ -f /usr/share/wayland-sessions/river.desktop ]; then
    SESSION_COMMAND="river"
    log_info "检测到 River"
elif command -v uwsm &>/dev/null && [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
    SESSION_COMMAND="uwsm start -- hyprland.desktop"
    log_info "检测到 Hyprland (通过 UWSM)"
elif [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
    SESSION_COMMAND="Hyprland"
    log_info "检测到 Hyprland"
elif [ -f /usr/share/wayland-sessions/sway.desktop ]; then
    SESSION_COMMAND="sway"
    log_info "检测到 Sway"
elif [ -f /usr/share/xsessions/plasma.desktop ]; then
    SESSION_COMMAND="startplasma-wayland"
    log_info "检测到 KDE Plasma"
elif [ -f /usr/share/xsessions/gnome.desktop ]; then
    SESSION_COMMAND="gnome-session"
    log_info "检测到 GNOME"
else
    log_warn "未检测到已知的桌面环境"
    log_warn "请手动编辑 /etc/systemd/system/seamless-login.service"
    log_warn "将 ExecStart 行修改为你的桌面启动命令"
    SESSION_COMMAND="echo 'Please configure your desktop session'"
fi

# ==============================================================================
# 3. 创建 systemd 服务
# ==============================================================================

if [ ! -f /etc/systemd/system/seamless-login.service ]; then
    log_info "创建 seamless-login systemd 服务..."

    # 获取用户的语言环境设置
    # 优先级: ~/.config/environment.d/ > /etc/locale.conf > 默认值
    USER_LANG=""

    # 1. 尝试从用户的 environment.d 配置读取
    if [ -d "$REAL_HOME/.config/environment.d" ]; then
        USER_LANG=$(grep -h '^LANG=' "$REAL_HOME/.config/environment.d"/*.conf 2>/dev/null | tail -1 | cut -d= -f2)
    fi

    # 2. 如果没有，从 /etc/locale.conf 读取
    if [ -z "$USER_LANG" ] && [ -f /etc/locale.conf ]; then
        USER_LANG=$(grep '^LANG=' /etc/locale.conf | cut -d= -f2)
    fi

    # 3. 如果还是空的，使用默认值
    [ -z "$USER_LANG" ] && USER_LANG="en_US.UTF-8"

    log_info "检测到语言环境: $USER_LANG"

    cat <<EOF | tee /etc/systemd/system/seamless-login.service >/dev/null
[Unit]
Description=Seamless Auto-Login
Documentation=https://github.com/anthropics/claude-code
Conflicts=getty@tty1.service
After=systemd-user-sessions.service getty@tty1.service plymouth-quit.service systemd-logind.service
PartOf=graphical.target

[Service]
Type=simple
ExecStart=/usr/local/bin/seamless-login $SESSION_COMMAND
Restart=always
RestartSec=2
StartLimitIntervalSec=30
StartLimitBurst=2
User=$REAL_USER
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal+console
PAMName=login

# 环境变量配置 - 保留用户的语言设置
Environment="LANG=$USER_LANG"
Environment="XDG_SESSION_TYPE=wayland"
Environment="XDG_SESSION_DESKTOP=river"
Environment="XDG_CURRENT_DESKTOP=river"

[Install]
WantedBy=graphical.target
EOF

    log_info "systemd 服务已创建"
else
    log_info "seamless-login.service 已存在"
fi

# ==============================================================================
# 4. 配置 Plymouth 延迟退出
# ==============================================================================

if [ ! -f /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf ]; then
    log_info "配置 Plymouth 延迟退出..."

    mkdir -p /etc/systemd/system/plymouth-quit.service.d
    tee /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf <<'EOF' >/dev/null
[Unit]
After=multi-user.target
EOF

    log_info "Plymouth 延迟退出已配置"
else
    log_info "Plymouth 延迟退出配置已存在"
fi

# ==============================================================================
# 5. 禁用冲突的服务
# ==============================================================================

log_info "配置 systemd 服务..."

# Mask plymouth-quit-wait.service
if ! systemctl is-enabled plymouth-quit-wait.service 2>/dev/null | grep -q masked; then
    systemctl mask plymouth-quit-wait.service
    log_info "已禁用 plymouth-quit-wait.service"
fi

# 禁用 getty@tty1.service
if ! systemctl is-enabled getty@tty1.service 2>/dev/null | grep -q disabled; then
    systemctl disable getty@tty1.service
    log_info "已禁用 getty@tty1.service"
fi

# 启用 seamless-login.service
if ! systemctl is-enabled seamless-login.service 2>/dev/null | grep -q enabled; then
    systemctl enable seamless-login.service
    log_info "已启用 seamless-login.service"
fi

systemctl daemon-reload

# ==============================================================================
# 完成
# ==============================================================================

echo ""
log_info "============================================"
log_info "无缝登录配置完成！"
log_info "============================================"
echo ""
log_info "配置详情:"
log_info "- 用户: $REAL_USER"
log_info "- 会话命令: $SESSION_COMMAND"
log_info "- 服务: seamless-login.service"
echo ""
log_info "下一步:"
log_info "1. 重启系统以启用无缝登录"
log_info "2. 如需修改会话命令，编辑: /etc/systemd/system/seamless-login.service"
log_info "3. 如需禁用自动登录: sudo systemctl disable seamless-login.service"
log_info "4. 如需恢复 getty: sudo systemctl enable getty@tty1.service"
echo ""

if [ "$SESSION_COMMAND" = "echo 'Please configure your desktop session'" ]; then
    log_warn "警告: 未检测到桌面环境，请手动配置服务文件"
fi
