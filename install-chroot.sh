#!/bin/bash
# Stage 1: Run in arch-chroot as root
# Critical system-level setup before first boot

set -e

# Simple output functions (no dependencies)
print_step() { echo -e "\n\033[0;34m==>\033[0m \033[1;37m$1\033[0m"; }
print_substep() { echo -e "  \033[0;35m->\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
print_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }

# Check running as root in chroot
if [ "$EUID" -ne 0 ]; then
    print_error "Must run as root in arch-chroot"
    exit 1
fi

if [ ! -f /etc/arch-release ]; then
    print_error "Not in Arch Linux environment"
    exit 1
fi

print_step "Arch Linux Post-Install - Stage 1 (chroot)"
echo "This script configures critical system settings"
echo ""

# 1. Install NetworkManager (CRITICAL!)
print_step "Install NetworkManager"
pacman -S --needed --noconfirm networkmanager
systemctl enable NetworkManager
print_success "NetworkManager installed and enabled"

# 2. Configure pacman
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
pacman -S --needed --noconfirm archlinuxcn-keyring

# 3. Install base-devel and git (needed for yay later)
print_step "Install base-devel and git"
pacman -S --needed --noconfirm base-devel git
print_success "base-devel and git installed"

# 4. Configure localization
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

# 5. Create install marker
echo "$(date '+%Y-%m-%d %H:%M:%S')" > /root/.arch-post-install-chroot-done

print_step "Stage 1 Complete!"
echo ""
echo "Next steps:"
echo "  1. Exit chroot"
echo "  2. Reboot into new system"
echo "  3. Login as regular user"
echo "  4. Run: ./install-user.sh"
echo ""
