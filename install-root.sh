#!/bin/bash
# Stage 1: Run as root in new system
# Critical system-level setup

set -e



# Simple output functions (no dependencies)
print_step() { echo -e "\n\033[0;34m==>\033[0m \033[1;37m$1\033[0m"; }
print_substep() { echo -e "  \033[0;35m->\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
print_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

# Check running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Must run as root"
    exit 1
fi

if [ ! -f /etc/arch-release ]; then
    print_error "Not in Arch Linux environment"
    exit 1
fi

print_step "Arch Linux Post-Install - Stage 1 (root)"
echo "This script configures critical system settings"
echo ""

# 1. Configure pacman
print_step "Configure pacman"

# Enable multilib
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sed -i '/^\[multilib\]/,/^Include/ s/^#//' /etc/pacman.conf
    print_success "multilib enabled"
fi

# Add archlinuxcn repo
if ! grep -q "^\[archlinuxcn\]" /etc/pacman.conf; then
    cat >> /etc/pacman.conf << 'EOF'

[archlinuxcn]
Server = https://repo.archlinuxcn.org/$arch
EOF
    print_success "archlinuxcn repo added"
fi

# Update database
pacman -Sy --noconfirm
print_success "pacman configured"

# 2. Configure localization
print_step "Configure localization"

# Uncomment locales
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

# Set system locale (English for system messages)
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set timezone
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

print_success "Localization configured"

# 3. Enable bluetooth
print_step "Configure bluetooth"

# Load bluetooth kernel modules
if ! lsmod | grep -q "^btusb"; then
    modprobe btusb 2>/dev/null || print_warning "btusb module not available (may need bluetooth hardware)"
fi

# Enable bluetooth service
if systemctl enable bluetooth.service; then
    print_success "Bluetooth service enabled"
else
    print_warning "Failed to enable bluetooth service"
fi

if systemctl start bluetooth.service; then
    print_success "Bluetooth service started"
else
    print_warning "Failed to start bluetooth service"
fi


print_step "Stage 1 Complete!"
echo ""
echo "Next steps:"
echo "  1. Run as user: ./install-user.sh"
echo ""
