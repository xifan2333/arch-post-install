#!/bin/bash

# Plymouth 完整安装脚本
# 整合 Plymouth 主题、无缝登录和引导器配置

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 sudo 运行此脚本"
    exit 1
fi

# 获取实际用户名
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo ~$REAL_USER)

echo ""
echo "============================================"
echo "  Plymouth 完整安装向导"
echo "============================================"
echo ""
log_info "用户: $REAL_USER"
log_info "脚本目录: $SCRIPT_DIR"
echo ""

# ==============================================================================
# 询问用户需要安装的组件
# ==============================================================================

echo "请选择要安装的组件:"
echo ""
echo "1. Plymouth 主题 + 引导器配置"
echo "2. 无缝登录配置（自动登录到桌面）"
echo "3. 完整安装（推荐）"
echo "4. 仅安装 Plymouth 主题"
echo ""
read -p "请输入选项 [1-4] (默认: 3): " INSTALL_OPTION
INSTALL_OPTION=${INSTALL_OPTION:-3}

INSTALL_PLYMOUTH=false
INSTALL_SEAMLESS=false

case $INSTALL_OPTION in
    1)
        INSTALL_PLYMOUTH=true
        ;;
    2)
        INSTALL_SEAMLESS=true
        ;;
    3)
        INSTALL_PLYMOUTH=true
        INSTALL_SEAMLESS=true
        ;;
    4)
        INSTALL_PLYMOUTH=true
        ;;
    *)
        log_error "无效的选项"
        exit 1
        ;;
esac

echo ""
log_info "安装选项:"
log_info "- Plymouth 主题: $INSTALL_PLYMOUTH"
log_info "- 无缝登录: $INSTALL_SEAMLESS"
echo ""

read -p "确认继续安装? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_info "安装已取消"
    exit 0
fi

echo ""

# ==============================================================================
# 执行安装
# ==============================================================================

STEP=1

if [ "$INSTALL_PLYMOUTH" = true ]; then
    log_step "[$STEP] 安装 Plymouth 主题和引导器配置"
    echo ""

    if [ -f "$SCRIPT_DIR/install-plymouth.sh" ]; then
        bash "$SCRIPT_DIR/install-plymouth.sh"
    else
        log_error "找不到 install-plymouth.sh"
        exit 1
    fi

    echo ""
    STEP=$((STEP + 1))
fi

if [ "$INSTALL_SEAMLESS" = true ]; then
    log_step "[$STEP] 配置无缝登录"
    echo ""

    if [ -f "$SCRIPT_DIR/install-seamless-login.sh" ]; then
        bash "$SCRIPT_DIR/install-seamless-login.sh"
    else
        log_error "找不到 install-seamless-login.sh"
        exit 1
    fi

    echo ""
    STEP=$((STEP + 1))
fi

# ==============================================================================
# 完成
# ==============================================================================

echo ""
echo "============================================"
log_info "安装完成！"
echo "============================================"
echo ""

if [ "$INSTALL_PLYMOUTH" = true ]; then
    log_info "✓ Plymouth 主题已安装"
fi

if [ "$INSTALL_SEAMLESS" = true ]; then
    log_info "✓ 无缝登录已配置"
fi

echo ""
log_info "下一步:"
echo ""

if [ "$INSTALL_PLYMOUTH" = true ]; then
    echo "  Plymouth 主题:"
    echo "  - 预览主题: sudo plymouthd --debug; sudo plymouth --show-splash; sleep 5; sudo plymouth quit"
    echo "  - 查看主题: plymouth-set-default-theme --list"
    echo "  - 切换主题: sudo plymouth-set-default-theme -R <主题名>"
    echo ""
fi

if [ "$INSTALL_SEAMLESS" = true ]; then
    echo "  无缝登录:"
    echo "  - 修改会话: sudo systemctl edit seamless-login.service"
    echo "  - 禁用自动登录: sudo systemctl disable seamless-login.service"
    echo "  - 恢复 getty: sudo systemctl enable getty@tty1.service"
    echo ""
fi

echo "  重启系统以查看效果:"
echo "  - sudo reboot"
echo ""

log_warn "注意: 无缝登录会自动登录到桌面，请确保已启用磁盘加密或其他安全措施"
echo ""
