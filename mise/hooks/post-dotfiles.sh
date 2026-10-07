#!/usr/bin/env bash
# Post-dotfiles hook: seed initial runtime configuration templates and sync themes
set -euo pipefail

# Retire the old command identities once, preserving user-owned files and history.
migrate_command_names() {
    local repo_root old_state new_state unit state relative target expected
    local needs_migration=false
    local -a retired_links=()
    repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
    old_state="${XDG_STATE_HOME:-$HOME/.local/state}/custom-stream-title"
    new_state="${XDG_STATE_HOME:-$HOME/.local/state}/custom-title"

    for relative in .local/bin/custom-blue .local/bin/custom-live .local/bin/custom-stream-title .local/share/applications/custom-live-config.desktop; do
        target="$HOME/$relative"
        expected="$repo_root/dotfiles/$relative"
        if [[ -L "$target" && "$(readlink -m -- "$target")" == "$expected" ]]; then
            retired_links+=("$target")
            needs_migration=true
        fi
    done
    if [[ -e "$old_state" || -L "$old_state" ]]; then needs_migration=true; fi
    [[ "$needs_migration" == true ]] || return 0

    # A running transient unit cannot be renamed. Require it to finish first.
    for unit in custom-live.service custom-stream-title.service; do
        state=$(systemctl --user show --property=ActiveState --value "$unit")
        case "$state" in
        inactive | failed) ;;
        active | activating | deactivating | reloading)
            custom-i18n get cli_migration_active "unit=$unit" >&2
            return 1
            ;;
        *)
            custom-i18n get cli_unavailable "name=$unit" >&2
            return 1
            ;;
        esac
    done
    if [[ -e "$old_state" || -L "$old_state" ]]; then
        if [[ -e "$new_state" || -L "$new_state" ]]; then
            custom-i18n get cli_migration_conflict "old=$old_state" "new=$new_state" >&2
            return 1
        fi
        [[ -d "$old_state" ]] || {
            custom-i18n get cli_unavailable "name=$old_state" >&2
            return 1
        }
        mv -T -- "$old_state" "$new_state"
    fi

    for target in "${retired_links[@]}"; do
        rm -- "$target"
    done
}
migrate_command_names

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
if [[ -x "dotfiles/.local/bin/custom-theme" ]]; then
    printf 'post-dotfiles: refreshing desktop theme...\n'
    current_theme=$(dotfiles/.local/bin/custom-theme current)
    if [[ -n "$current_theme" ]]; then
        dotfiles/.local/bin/custom-theme refresh
    else
        dotfiles/.local/bin/custom-theme set tokyo-night
    fi
fi

# Seed once, preserving the selected font pair and regenerating derived fragments.
printf 'post-dotfiles: initializing desktop fonts...\n'
custom-font init "JetBrainsMono Nerd Font" "Sarasa Mono SC"
