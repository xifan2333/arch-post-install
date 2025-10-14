#!/bin/bash
# Configure localization (locale, timezone)

print_substep "Configure localization..."

# Configure locales
print_substep "Configure locale..."
if ! grep -q "^zh_CN.UTF-8 UTF-8" /etc/locale.gen; then
    sudo sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
fi

if ! grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen; then
    sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
fi

sudo locale-gen

# Set system locale (keep English for system, Chinese can be set per-user)
if [ ! -f /etc/locale.conf ] || ! grep -q "LANG=" /etc/locale.conf; then
    echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf
fi

# Set timezone to Asia/Shanghai
print_substep "Set timezone Asia/Shanghai..."
sudo timedatectl set-timezone Asia/Shanghai
sudo timedatectl set-ntp true

print_success "Localization configured"
