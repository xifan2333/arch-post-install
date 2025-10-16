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

# Install packages from packages.txt
install_from_list() {
    local pkg_file="$SCRIPT_DIR/packages.txt"

    if [ ! -f "$pkg_file" ]; then
        print_error "Package list not found: $pkg_file"
        return 1
    fi

    local pacman_pkgs=""
    local aur_pkgs=""

    # Parse package list
    while IFS='|' read -r package source; do
        # Skip comments, empty lines, and section headers
        [[ "$package" =~ ^#.*$ ]] && continue
        [[ "$package" =~ ^\[.*\]$ ]] && continue
        [[ -z "$package" ]] && continue

        # Trim whitespace
        package=$(echo "$package" | xargs)
        source=$(echo "$source" | xargs)

        if [ "$source" = "pacman" ]; then
            pacman_pkgs="$pacman_pkgs $package"
        elif [ "$source" = "aur" ]; then
            aur_pkgs="$aur_pkgs $package"
        fi
    done < "$pkg_file"

    # Install pacman packages
    if [ -n "$pacman_pkgs" ]; then
        print_step "Install packages from official repositories"
        sudo pacman -S --needed --noconfirm $pacman_pkgs
        print_success "Official packages installed"
    fi

    # Install AUR packages
    if [ -n "$aur_pkgs" ]; then
        print_step "Install packages from AUR"
        yay -S --needed --noconfirm $aur_pkgs
        print_success "AUR packages installed"
    fi
}

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

# Install packages from package list
install_from_list

# Refresh font cache
fc-cache -fv > /dev/null

# Download RIME-LMDG language model
print_step "Download RIME-LMDG language model"
RIME_DIR="$SCRIPT_DIR/dotfiles/fcitx5/.config/fcitx5/rime"

mkdir -p "$RIME_DIR"

if curl -L -o "$RIME_DIR/wanxiang-lts-zh-hans.gram" "https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram"; then
    print_success "RIME-LMDG language model downloaded"
else
    print_warning "Failed to download RIME-LMDG language model"
fi

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

# Gen ssh

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
print_substep "2. Press Ctrl+Space to toggle input method"
print_substep "3. Start River: river (or use display manager)"
echo ""
