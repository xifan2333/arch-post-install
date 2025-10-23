#!/bin/bash

# Plymouth 主题完整安装脚本
# 包含主题安装、mkinitcpio 配置和引导器配置

set -e

THEME_NAME="custom-theme"
THEME_DIR="/usr/share/plymouth/themes/${THEME_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# 获取实际用户名（即使使用 sudo）
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo ~$REAL_USER)

log_info "开始安装 Plymouth 主题: ${THEME_NAME}"

# ==============================================================================
# 1. 安装 Plymouth 包
# ==============================================================================

log_info "检查 Plymouth 包..."
if ! pacman -Qi plymouth &>/dev/null; then
    log_info "安装 Plymouth..."
    pacman -S --noconfirm --needed plymouth
else
    log_info "Plymouth 已安装"
fi

# ==============================================================================
# 2. 安装主题文件
# ==============================================================================

log_info "安装主题文件..."
mkdir -p "${THEME_DIR}"
cp "${SCRIPT_DIR}/${THEME_NAME}/"*.png "${THEME_DIR}/"
cp "${SCRIPT_DIR}/${THEME_NAME}/${THEME_NAME}.plymouth" "${THEME_DIR}/"
cp "${SCRIPT_DIR}/${THEME_NAME}/${THEME_NAME}.script" "${THEME_DIR}/"
chmod 644 "${THEME_DIR}"/*

# ==============================================================================
# 3. 配置 mkinitcpio
# ==============================================================================

log_info "配置 mkinitcpio hooks..."

# 检查是否已经添加了 plymouth hook
if ! grep -Eq '^HOOKS=.*plymouth' /etc/mkinitcpio.conf; then
    # 备份原始配置
    backup_timestamp=$(date +"%Y%m%d%H%M%S")
    cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.${backup_timestamp}"
    log_info "已备份 mkinitcpio.conf 到 /etc/mkinitcpio.conf.bak.${backup_timestamp}"

    # 在 base udev 或 base systemd 后添加 plymouth
    if grep "^HOOKS=" /etc/mkinitcpio.conf | grep -q "base systemd"; then
        sed -i '/^HOOKS=/s/base systemd/base systemd plymouth/' /etc/mkinitcpio.conf
        log_info "已添加 plymouth hook（systemd 模式）"
    elif grep "^HOOKS=" /etc/mkinitcpio.conf | grep -q "base udev"; then
        sed -i '/^HOOKS=/s/base udev/base udev plymouth/' /etc/mkinitcpio.conf
        log_info "已添加 plymouth hook（udev 模式）"
    else
        log_warn "无法自动添加 plymouth hook，请手动编辑 /etc/mkinitcpio.conf"
    fi
else
    log_info "plymouth hook 已存在"
fi

# ==============================================================================
# 4. 设置默认主题
# ==============================================================================

log_info "设置 Plymouth 默认主题..."
plymouth-set-default-theme "${THEME_NAME}"

# ==============================================================================
# 5. 配置引导器
# ==============================================================================

log_info "配置引导器..."

BOOTLOADER_CONFIGURED=false

# 检测 Limine
if command -v limine &>/dev/null; then
    log_info "检测到 Limine 引导器"

    # 查找 limine 配置文件
    if [[ -f /boot/EFI/BOOT/limine.conf ]]; then
        limine_config="/boot/EFI/BOOT/limine.conf"
    elif [[ -f /boot/EFI/limine/limine.conf ]]; then
        limine_config="/boot/EFI/limine/limine.conf"
    elif [[ -f /boot/limine/limine.conf ]]; then
        limine_config="/boot/limine/limine.conf"
    fi

    if [[ -n "$limine_config" ]]; then
        # 检查 cmdline 是否已包含 splash quiet
        if ! grep -q "splash" "$limine_config"; then
            # 获取当前 cmdline
            CMDLINE=$(grep "^[[:space:]]*cmdline:" "$limine_config" | head -1 | sed 's/^[[:space:]]*cmdline:[[:space:]]*//')

            # 添加 splash quiet
            if [[ -n "$CMDLINE" ]]; then
                sed -i "s|cmdline:.*|cmdline: $CMDLINE splash quiet|" "$limine_config"
                log_info "已添加 splash quiet 到 Limine 配置"
            fi
        else
            log_info "Limine 配置已包含 splash 参数"
        fi
        BOOTLOADER_CONFIGURED=true
    fi

# 检测 systemd-boot
elif [ -d "/boot/loader/entries" ]; then
    log_info "检测到 systemd-boot 引导器"

    for entry in /boot/loader/entries/*.conf; do
        if [ -f "$entry" ]; then
            # 跳过 fallback 条目
            if [[ "$(basename "$entry")" == *"fallback"* ]]; then
                continue
            fi

            # 检查是否已包含 splash
            if ! grep -q "splash" "$entry"; then
                sed -i '/^options/ s/$/ splash quiet/' "$entry"
                log_info "已配置: $(basename "$entry")"
            fi
        fi
    done
    BOOTLOADER_CONFIGURED=true

# 检测 GRUB
elif [ -f "/etc/default/grub" ]; then
    log_info "检测到 GRUB 引导器"

    if ! grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*splash" /etc/default/grub; then
        # 备份 GRUB 配置
        backup_timestamp=$(date +"%Y%m%d%H%M%S")
        cp /etc/default/grub "/etc/default/grub.bak.${backup_timestamp}"
        log_info "已备份 GRUB 配置到 /etc/default/grub.bak.${backup_timestamp}"

        # 获取当前 cmdline
        current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d'"' -f2)

        # 添加 splash 和 quiet
        new_cmdline="$current_cmdline"
        if [[ ! "$current_cmdline" =~ splash ]]; then
            new_cmdline="$new_cmdline splash"
        fi
        if [[ ! "$current_cmdline" =~ quiet ]]; then
            new_cmdline="$new_cmdline quiet"
        fi

        # 去除首尾空格
        new_cmdline=$(echo "$new_cmdline" | xargs)

        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"/" /etc/default/grub

        log_info "重新生成 GRUB 配置..."
        grub-mkconfig -o /boot/grub/grub.cfg
        BOOTLOADER_CONFIGURED=true
    else
        log_info "GRUB 配置已包含 splash 参数"
        BOOTLOADER_CONFIGURED=true
    fi

# 检测 UKI (cmdline.d)
elif [ -d "/etc/cmdline.d" ]; then
    log_info "检测到 UKI 设置 (cmdline.d)"

    if ! grep -q splash /etc/cmdline.d/*.conf 2>/dev/null; then
        echo "splash" | tee -a /etc/cmdline.d/plymouth.conf >/dev/null
        log_info "已添加 splash 参数"
    fi
    if ! grep -q quiet /etc/cmdline.d/*.conf 2>/dev/null; then
        echo "quiet" | tee -a /etc/cmdline.d/plymouth.conf >/dev/null
        log_info "已添加 quiet 参数"
    fi
    BOOTLOADER_CONFIGURED=true

# 检测 UKI (kernel/cmdline)
elif [ -f "/etc/kernel/cmdline" ]; then
    log_info "检测到 UKI 设置 (kernel/cmdline)"

    # 备份
    backup_timestamp=$(date +"%Y%m%d%H%M%S")
    cp /etc/kernel/cmdline "/etc/kernel/cmdline.bak.${backup_timestamp}"

    current_cmdline=$(cat /etc/kernel/cmdline)
    new_cmdline="$current_cmdline"

    if [[ ! "$current_cmdline" =~ splash ]]; then
        new_cmdline="$new_cmdline splash"
    fi
    if [[ ! "$current_cmdline" =~ quiet ]]; then
        new_cmdline="$new_cmdline quiet"
    fi

    new_cmdline=$(echo "$new_cmdline" | xargs)
    echo "$new_cmdline" | tee /etc/kernel/cmdline >/dev/null
    log_info "已更新内核命令行参数"
    BOOTLOADER_CONFIGURED=true
fi

if [ "$BOOTLOADER_CONFIGURED" = false ]; then
    log_warn "未检测到支持的引导器"
    log_warn "请手动添加以下内核参数: splash quiet"
fi

# ==============================================================================
# 6. 重新生成 initramfs
# ==============================================================================

log_info "重新生成 initramfs..."
if command -v limine &>/dev/null && command -v limine-update &>/dev/null; then
    limine-update
else
    mkinitcpio -P
fi

# ==============================================================================
# 完成
# ==============================================================================

echo ""
log_info "============================================"
log_info "Plymouth 主题安装完成！"
log_info "============================================"
echo ""
log_info "主题名称: ${THEME_NAME}"
log_info "主题位置: ${THEME_DIR}"
echo ""
log_info "下一步:"
log_info "1. 重启系统查看启动画面"
log_info "2. 如需预览: sudo plymouthd --debug; sudo plymouth --show-splash; sleep 5; sudo plymouth quit"
log_info "3. 查看可用主题: plymouth-set-default-theme --list"
log_info "4. 切换主题: sudo plymouth-set-default-theme -R <主题名>"
echo ""

if [ "$BOOTLOADER_CONFIGURED" = false ]; then
    log_warn "注意: 引导器配置可能需要手动完成"
fi
