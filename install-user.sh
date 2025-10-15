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

# Check network
if ! ping -c 1 archlinux.org &> /dev/null; then
    print_error "No network connection"
    exit 1
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
    librime

print_success "fcitx5 installed"

# Install rime-ice
print_step "Install rime-ice (雾凇拼音)"
RIME_ICE_DIR="$HOME/.cache/rime-ice"
FCITX_RIME_DIR="$HOME/.local/share/fcitx5/rime"

rm -rf "$RIME_ICE_DIR"

if git clone https://github.com/iDvel/rime-ice.git --depth=1 "$RIME_ICE_DIR"; then
    cd "$RIME_ICE_DIR" || exit 1

    # Enable comma/period page turning
    # The following sed command uncomments lines in default.yaml that allow using comma/period for page turning in Rime.
    sed -i 's/# \(- { when: \(paging\|has_menu\), accept: \(comma\|period\), send: Page_\(Up\|Down\) }\)/\1/' default.yaml

    # Change page size to 9
    sed -i 's/page_size: 5/page_size: 9/' default.yaml

    # Copy to fcitx5
    mkdir -p "$FCITX_RIME_DIR"
    cp -r "$RIME_ICE_DIR"/* "$FCITX_RIME_DIR/"

    cd "$SCRIPT_DIR"
    print_success "rime-ice installed"
else
    print_error "Failed to clone rime-ice"
    exit 1
fi

# Configure fcitx5 environment
print_step "Configure fcitx5 environment"
if [ ! -f "$HOME/.xprofile" ] || ! grep -q "fcitx" "$HOME/.xprofile"; then
    cat >> "$HOME/.xprofile" << 'EOF'

# Fcitx5 input method
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
EOF
    print_success "fcitx5 env added to .xprofile"
fi

# Configure fcitx5 UI
mkdir -p "$HOME/.config/fcitx5/conf"
cat > "$HOME/.config/fcitx5/conf/classicui.conf" << 'EOF'
Vertical Candidate List=False
PerScreenDPI=False
Font="Noto Sans Mono 13"
Theme=adwaita-dark
EOF
print_success "fcitx5 UI configured"

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
