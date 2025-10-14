#!/bin/bash
# Install and configure themes

print_substep "Install themes..."

THEME_PACKAGES=(
    # GTK themes
    arc-gtk-theme
    papirus-icon-theme

    # Qt theme engine
    qt5ct
    kvantum

    # Cursor theme
    xcursor-themes
)

sudo pacman -S --needed --noconfirm "${THEME_PACKAGES[@]}"

# Set GTK theme to dark
print_substep "Configure GTK dark theme..."
gsettings set org.gnome.desktop.interface gtk-theme "Arc-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true

print_success "Themes installed"
