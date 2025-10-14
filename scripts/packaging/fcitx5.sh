#!/bin/bash
# Install fcitx5 and rime-ice

print_substep "Install fcitx5 core..."

# Core fcitx5 packages
FCITX5_PACKAGES=(
    fcitx5
    fcitx5-gtk
    fcitx5-qt
    fcitx5-configtool
    fcitx5-rime
    librime
)

sudo pacman -S --needed --noconfirm "${FCITX5_PACKAGES[@]}"

# Install fcitx5 theme (optional, may fail)
print_substep "Install fcitx5 theme..."
yay -S --needed --noconfirm fcitx5-skin-adwaita-dark || print_warning "Theme install failed, skip"

# Install rime-ice - prefer manual install (AUR package build is very slow)
print_substep "Install rime-ice..."
RIME_ICE_DIR="$HOME/.cache/rime-ice"
FCITX_RIME_DIR="$HOME/.local/share/fcitx5/rime"
ORIGINAL_DIR="$(pwd)"

# Clean old installation
rm -rf "$RIME_ICE_DIR"

# Clone rime-ice
if git clone https://github.com/iDvel/rime-ice.git --depth=1 "$RIME_ICE_DIR"; then
    cd "$RIME_ICE_DIR"

    # Enable comma/period page turning
    sed -i 's/# \(- { when: \(paging\|has_menu\), accept: \(comma\|period\), send: Page_\(Up\|Down\) }\)/\1/' default.yaml

    # Change page size to 9
    sed -i 's/page_size: 5/page_size: 9/' default.yaml

    # Copy to fcitx5 directory
    mkdir -p "$FCITX_RIME_DIR"
    cp -r "$RIME_ICE_DIR"/* "$FCITX_RIME_DIR/"

    cd "$ORIGINAL_DIR"
    print_success "rime-ice installed"
else
    print_error "Failed to install rime-ice"
    cd "$ORIGINAL_DIR"
    exit 1
fi

# Download language model (optional, don't fail if it doesn't work)
print_substep "Download language model..."
LMDG_URL="https://github.com/amzxyz/RIME-LMDG/releases/latest/download/amz-v2n3m1-zh-hans.gram"
LMDG_FILE="$HOME/.local/share/fcitx5/rime/amz-v2n3m1-zh-hans.gram"

if wget --timeout=30 -q "$LMDG_URL" -O "$LMDG_FILE" 2>/dev/null; then
    # Create custom config for language model
    cat > "$HOME/.local/share/fcitx5/rime/rime_ice.custom.yaml" << 'EOF'
patch:
  grammar:
    language: amz-v2n3m1-zh-hans
    collocation_max_length: 5
    collocation_min_length: 2
  translator/contextual_suggestions: true
  translator/max_homophones: 7
  translator/max_homographs: 7
EOF
    print_success "Language model downloaded"
else
    print_warning "Language model download failed (optional, skip)"
fi

print_success "fcitx5 installed"
