#!/usr/bin/env bash
# Post-dotfiles hook: seed initial runtime configuration templates and sync themes
set -euo pipefail

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

# Sync fcitx5 theme in a standalone, self-contained way
fcitx5_theme_sync="dotfiles/.local/bin/arch-theme-sync-fcitx5"
if [[ ! -x "$fcitx5_theme_sync" ]]; then
    fcitx5_theme_sync="dotfiles/.local/bin/fcitx5-theme-sync"
fi
if [[ -x "$fcitx5_theme_sync" ]]; then
    printf 'post-dotfiles: syncing fcitx5 theme...\n'
    "$fcitx5_theme_sync"
fi
