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
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch
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
hash -r 2>/dev/null || true

# 6. Build and install seamless-login VT switcher before systemd services stage
REPO_ROOT="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
CC="${CC:-gcc}"
if ! command -v "$CC" &>/dev/null && [[ -x /usr/bin/gcc ]]; then
    CC="/usr/bin/gcc"
fi

if [[ -f "$REPO_ROOT/src/seamless-login.c" ]] && (command -v "$CC" &>/dev/null || [[ -x "$CC" ]]); then
    if [[ ! -x "/usr/local/bin/seamless-login" || "$REPO_ROOT/src/seamless-login.c" -nt "/usr/local/bin/seamless-login" ]]; then
        printf 'pre-packages: building seamless-login VT switcher...\n'
        tmp_bin=$(mktemp)
        if "$CC" -O2 "$REPO_ROOT/src/seamless-login.c" -o "$tmp_bin"; then
            $SUDO install -D -m 0755 "$tmp_bin" "/usr/local/bin/seamless-login"
        fi
        rm -f "$tmp_bin"
    fi
fi

# 7. Configure dynamic user drop-in for arch-seamless-login.service
target_user="${SUDO_USER:-$USER}"
if [[ "$target_user" == "root" ]]; then
    target_user=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd || true)
fi

if [[ -n "$target_user" ]]; then
    printf 'pre-packages: configuring arch-seamless-login user drop-in for "%s"...\n' "$target_user"
    $SUDO mkdir -p /etc/systemd/system/arch-seamless-login.service.d
    cat <<EOF | $SUDO tee /etc/systemd/system/arch-seamless-login.service.d/user.conf >/dev/null
[Service]
User=$target_user
EOF
fi
