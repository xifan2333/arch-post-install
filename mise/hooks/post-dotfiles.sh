#!/usr/bin/env bash
# Post-dotfiles hook: seed initial runtime configuration templates and sync themes
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    SUDO=""
elif command -v sudo &>/dev/null; then
    SUDO="sudo"
elif command -v pkexec &>/dev/null; then
    SUDO="pkexec"
else
    SUDO=""
fi

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

seed_example() {
    local src="$1" dest="$2" mode="${3:-0644}"
    if [[ -e $dest ]]; then
        return 0
    fi
    install -D -m "$mode" "$src" "$dest"
    printf 'post-dotfiles: seeded %s\n' "$dest"
}

seed_example dotfiles/.config/screenrecord/title.conf.example "$config_home/screenrecord/title.conf"
seed_example dotfiles/.config/screenrecord/keys.conf.example "$config_home/screenrecord/keys.conf"
seed_example dotfiles/.config/screenrecord/captions.conf.example "$config_home/screenrecord/captions.conf"
seed_example dotfiles/.config/screenrecord/camera.conf.example "$config_home/screenrecord/camera.conf"
seed_example dotfiles/.config/livestream/config.json.example "$config_home/livestream/config.json" 0600
seed_example dotfiles/.config/dmnotifier/config.yaml.example "$config_home/dmnotifier/config.yaml"
seed_example dotfiles/.config/vinput/config.json.example "$config_home/vinput/config.json" 0600
seed_example dotfiles/.config/qutebrowser/translate.json.example "$config_home/qutebrowser/translate.json" 0600

# Seed Plymouth binary image assets if Plymouth theme directory exists
plymouth_target="/usr/share/plymouth/themes/arch"
if [[ -d "$plymouth_target" && -d "mise/plymouth/themes/arch" ]]; then
    for img in mise/plymouth/themes/arch/*.png; do
        [[ -f "$img" ]] || continue
        base=$(basename "$img")
        $SUDO install -D -m 0644 "$img" "$plymouth_target/$base"
    done
    if command -v plymouth-set-default-theme &>/dev/null; then
        $SUDO plymouth-set-default-theme arch 2>/dev/null || true
    fi
fi

# Compile and install seamless-login helper if src exists
if [[ -f "src/seamless-login.c" ]] && command -v gcc &>/dev/null; then
    if [[ ! -x "/usr/local/bin/seamless-login" || "src/seamless-login.c" -nt "/usr/local/bin/seamless-login" ]]; then
        printf 'post-dotfiles: building seamless-login VT switcher...\n'
        tmp_bin=$(mktemp)
        if gcc -O2 src/seamless-login.c -o "$tmp_bin" 2>/dev/null; then
            $SUDO install -D -m 0755 "$tmp_bin" "/usr/local/bin/seamless-login" 2>/dev/null || true
        fi
        rm -f "$tmp_bin"
    fi
fi

# Apply active or default desktop theme (renders templates to ~/.local/state/theme)
if [[ -x "dotfiles/.local/bin/arch-theme-set" ]]; then
    printf 'post-dotfiles: refreshing desktop theme...\n'
    dotfiles/.local/bin/arch-theme-set --refresh 2>/dev/null || dotfiles/.local/bin/arch-theme-set tokyo-night
fi
