#!/bin/bash
# Install Wayland environment (River, Waybar, Foot)

print_substep "Install Wayland..."

WAYLAND_PACKAGES=(
    # Compositor
    river

    # Status bar
    waybar

    # Terminal
    foot

    # Wayland utilities
    wl-clipboard
    xdg-desktop-portal-wlr
    qt5-wayland
    qt6-wayland
)

sudo pacman -S --needed --noconfirm "${WAYLAND_PACKAGES[@]}"

print_success "Wayland installed"
