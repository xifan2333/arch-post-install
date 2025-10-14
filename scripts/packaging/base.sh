#!/bin/bash
# Install base system packages

print_substep "Install base packages..."

PACKAGES=(
    git
    base-devel
    wget
    curl
    neovim
    btop
    stow
)

sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

print_success "Base packages installed"
