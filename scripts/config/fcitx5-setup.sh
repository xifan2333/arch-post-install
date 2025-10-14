#!/bin/bash
# Configure fcitx5 environment

print_substep "Configure fcitx5 env..."

# Create or update .xprofile
XPROFILE="$HOME/.xprofile"

if [ ! -f "$XPROFILE" ] || ! grep -q "fcitx" "$XPROFILE"; then
    cat >> "$XPROFILE" << 'EOF'

# Fcitx5 input method
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
EOF
    print_success "fcitx5 env added to .xprofile"
else
    print_info "fcitx5 env already exists"
fi

# Configure fcitx5 UI
print_substep "Configure fcitx5 UI..."
mkdir -p "$HOME/.config/fcitx5/conf"

cat > "$HOME/.config/fcitx5/conf/classicui.conf" << 'EOF'
# 横向候选列表
Vertical Candidate List=False

# 禁止字体随着 DPI 缩放
PerScreenDPI=False

# 字体和大小
Font="Noto Sans Mono 13"

# 主题
Theme=adwaita-dark
EOF

print_success "fcitx5 configured"
print_info "Logout to apply input method"
