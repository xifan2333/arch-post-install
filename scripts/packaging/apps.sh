#!/bin/bash
# Install applications

print_substep "Install applications..."

APPS=(
    # Browser
    firefox
    firefox-i18n-zh-cn

    # Code editor
    code

    # Media
    mpv
    vlc

    # PDF reader
    zathura
    zathura-pdf-mupdf
)

sudo pacman -S --needed --noconfirm "${APPS[@]}"

# Install VSCode from AUR if official package not available
if ! command -v code &> /dev/null; then
    print_substep "Install VSCode from AUR..."
    yay -S --needed --noconfirm visual-studio-code-bin || print_warning "VSCode install failed"
fi

print_success "Applications installed"
