#!/usr/bin/env bash
# Pre-packages setup hook: ensure build dependencies, official archlinuxcn repo, and yay
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

# 1. Ensure pacman keyring exists and is valid
if [[ ! -s /etc/pacman.d/gnupg/pubring.gpg ]]; then
    printf 'pre-packages: initializing pacman keyring...\n'
    $SUDO rm -rf /etc/pacman.d/gnupg
    $SUDO pacman-key --init
    $SUDO pacman-key --populate archlinux
fi

# 2. Update official archlinux-keyring and install base-devel build prerequisites
if ! pacman -Q base-devel &>/dev/null; then
    printf 'pre-packages: installing base-devel build prerequisites...\n'
    $SUDO pacman -Sy --needed --noconfirm archlinux-keyring base-devel
fi

# 3. Configure official archlinuxcn repository in /etc/pacman.conf
if ! grep -q '^\s*\[archlinuxcn\]' /etc/pacman.conf; then
    printf 'pre-packages: configuring official archlinuxcn repository...\n'
    cat <<'REPO' | $SUDO tee -a /etc/pacman.conf >/dev/null

[archlinuxcn]
Server = https://repo.archlinuxcn.org/$arch
REPO
fi

# 4. Install archlinuxcn-keyring
if ! pacman -Q archlinuxcn-keyring &>/dev/null; then
    printf 'pre-packages: installing archlinuxcn-keyring...\n'
    $SUDO pacman -Sy --needed --noconfirm archlinuxcn-keyring
fi

# 5. Install yay (prebuilt binary from archlinuxcn)
if ! pacman -Q yay &>/dev/null; then
    printf 'pre-packages: installing yay from archlinuxcn...\n'
    $SUDO pacman -S --needed --noconfirm yay
fi
