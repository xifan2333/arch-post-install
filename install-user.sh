#!/bin/bash
# Stage 2: Run as regular user after first boot
# Install desktop environment and user applications

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Simple output functions
print_step() { echo -e "\n\033[0;34m==>\033[0m \033[1;37m$1\033[0m"; }
print_substep() { echo -e "  \033[0;35m->\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
print_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

# Check not running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Do NOT run as root. Run as regular user."
    exit 1
fi

# Check network (try multiple methods)
if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null && ! ping -c 1 -W 2 archlinux.org &> /dev/null; then
    print_warning "Network check failed, but continuing anyway"
    print_info "If downloads fail, check your network connection"
fi

print_step "Arch Linux Post-Install - Stage 2 (user)"
echo "Installing desktop environment and applications"
echo ""

# Install yay if not present
if ! command -v yay &> /dev/null; then
    print_step "Install yay AUR helper"

    cd /tmp || exit 1
    rm -rf yay

    if git clone https://aur.archlinux.org/yay.git; then
        cd yay || exit 1
        if makepkg -si --noconfirm; then
            print_success "yay installed"
        else
            print_error "yay build failed"
            exit 1
        fi
        cd /tmp
        rm -rf yay
    else
        print_error "Failed to clone yay"
        exit 1
    fi
fi

# Install packages by category
print_step "Install fonts"
sudo pacman -S --needed --noconfirm \
    noto-fonts-cjk \
    noto-fonts-emoji \
    adobe-source-han-sans-cn-fonts \
    adobe-source-han-serif-cn-fonts \
    wqy-microhei \
    wqy-zenhei

fc-cache -fv > /dev/null
print_success "Fonts installed"

# Install fcitx5
print_step "Install fcitx5"
sudo pacman -S --needed --noconfirm \
    fcitx5 \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-configtool \
    fcitx5-rime \
    librime \
    librime-plugin-octagram

print_success "fcitx5 installed"

# Download RIME-LMDG language model
print_step "Download RIME-LMDG language model"
RIME_DIR="$SCRIPT_DIR/dotfiles/fcitx5/.config/fcitx5/rime"

mkdir -p "$RIME_DIR"

if curl -L -o "$RIME_DIR/wanxiang-lts-zh-hans.gram" "https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram"; then
    print_success "RIME-LMDG language model downloaded"
else
    print_warning "Failed to download RIME-LMDG language model"
fi

# Install Wayland environment
print_step "Install Wayland (River, Foot, etc.)"
sudo pacman -S --needed --noconfirm \
    river \
    foot \
    waybar \
    wl-clipboard \
    xdg-desktop-portal-wlr \
    qt5-wayland \
    qt6-wayland

print_success "Wayland environment installed"

# Install desktop tools
print_step "Install desktop tools"
sudo pacman -S --needed --noconfirm \
    swaylock \
    wofi \
    dunst \
    imv \
    grim \
    slurp

print_success "Desktop tools installed"

# Install applications
print_step "Install applications"
sudo pacman -S --needed --noconfirm \
    firefox \
    firefox-i18n-zh-cn \
    mpv \
    zathura \
    zathura-pdf-mupdf

print_success "Applications installed"

# Configure Git
print_step "Configure Git"
if ! git config --global user.name &> /dev/null; then
    read -p "Git username: " git_user
    git config --global user.name "$git_user"
fi

if ! git config --global user.email &> /dev/null; then
    read -p "Git email: " git_email
    git config --global user.email "$git_email"
fi

git config --global core.editor vim
git config --global init.defaultBranch main
print_success "Git configured"

# Deploy dotfiles
print_step "Deploy dotfiles"
if [ -f "$SCRIPT_DIR/install-dotfiles.sh" ]; then
    bash "$SCRIPT_DIR/install-dotfiles.sh"
    print_success "Dotfiles deployed"
else
    print_warning "install-dotfiles.sh not found, skip"
fi

# Done
echo ""
print_step "Installation Complete!"
echo ""
print_info "Next steps:"
print_substep "1. Logout and login again"
print_substep "2. fcitx5 should auto-start"
print_substep "3. Run: fcitx5-configtool"
print_substep "   - Add Input Method"
print_substep "   - Search 'rime' and add it"
print_substep "4. Test input with Ctrl+Space"
print_substep "5. Start River: river (or use display manager)"
echo ""
