#!/bin/bash
# Install Chinese fonts

print_substep "Install fonts..."

FONTS=(
    # Adobe Source Han fonts
    adobe-source-han-sans-cn-fonts
    adobe-source-han-serif-cn-fonts

    # Noto CJK fonts
    noto-fonts-cjk
    noto-fonts-emoji

    # WenQuanYi fonts
    wqy-microhei
    wqy-zenhei

    # Other useful fonts
    ttf-dejavu
    ttf-liberation
    noto-fonts
)

sudo pacman -S --needed --noconfirm "${FONTS[@]}"

# Install additional fonts from AUR (optional)
print_substep "Install TsangerType fonts..."
yay -S --needed --noconfirm ttf-tsangertype-tc || print_warning "TsangerType install failed (optional, skip)"

# Rebuild font cache
print_substep "Rebuild font cache..."
fc-cache -fv 2>&1 | head -5

print_success "Fonts installed"
