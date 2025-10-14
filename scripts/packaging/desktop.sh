#!/bin/bash
# Install desktop utilities

print_substep "Install desktop tools..."

DESKTOP_PACKAGES=(
    # Lock screen
    swaylock

    # Launcher
    wofi

    # File manager
    thunar
    thunar-volman
    thunar-archive-plugin

    # Notifications
    dunst

    # Image viewer
    imv

    # Screenshot
    grim
    slurp

    # Archive support
    file-roller
    p7zip
    unzip
    unrar
)

sudo pacman -S --needed --noconfirm "${DESKTOP_PACKAGES[@]}"

print_success "Desktop tools installed"
