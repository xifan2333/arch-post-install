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

# Ensure systemd boots into graphical.target directly for seamless desktop autologin
if command -v systemctl &>/dev/null; then
    if [[ "$(systemctl get-default 2>/dev/null || true)" != "graphical.target" ]]; then
        printf 'post-dotfiles: setting default systemd target to graphical.target...\n'
        $SUDO systemctl set-default graphical.target 2>/dev/null || true
    fi
fi

# Ensure global user tools declared in ~/.config/mise/config.toml are installed
if command -v mise &>/dev/null; then
    printf 'post-dotfiles: converging global user CLI tools via mise...\n'
    mise install -g -y 2>/dev/null || true
fi

# Apply active or default desktop theme (renders templates to ~/.local/state/theme)
if [[ -x "dotfiles/.local/bin/arch-theme" ]]; then
    printf 'post-dotfiles: refreshing desktop theme...\n'
    dotfiles/.local/bin/arch-theme refresh 2>/dev/null || dotfiles/.local/bin/arch-theme tokyo-night
fi

# Seed once, preserving the selected font pair and regenerating derived fragments.
printf 'post-dotfiles: initializing desktop fonts...\n'
custom-font init "JetBrainsMono Nerd Font" "Sarasa Mono SC"
