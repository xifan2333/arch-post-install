# Post-Install & Machine Provisioning Guide

This guide describes how to turn a clean, minimal Arch Linux installation into a fully featured Suckless River desktop workstation using `mise bootstrap`.

---

## 1. Machine Baseline (Post-archinstall)

When installing Arch Linux using the official guided installer (`archinstall`), select:
- **Profile**: `Minimal` (no desktop environment installed).
- **Audio**: `PipeWire`.
- **Network**: `systemd-networkd` / `iwd` or copy ISO configuration.
- **User**: Add an ordinary user with `sudo` privileges.

After installation completes, reboot into the machine and log in at the TTY console.

---

## 2. One-Command Machine Provisioning

On the newly installed machine:

```bash
# 1. Install mise (if not already installed)
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

# 2. Clone this repository
git clone https://github.com/xifan2333/arch-post-install.git ~/Code/arch-post-install
cd ~/Code/arch-post-install

# 3. Trust and execute declarative bootstrap
mise trust
mise bootstrap --yes
```

---

## 3. What `mise bootstrap` Does (Lifecycle Sequence)

Mise executes the declarative convergence pipeline in strict order:

1. **`[bootstrap.hooks.pre-packages]`** (`mise/hooks/pre-packages.sh`):
   - Initializes pacman keyring if corrupted/empty.
   - Updates `archlinux-keyring` and installs `base-devel` build prerequisites.
   - Configures the official `[archlinuxcn]` repository (`https://repo.archlinuxcn.org/$arch`).
   - Installs `archlinuxcn-keyring`.
   - Installs prebuilt `yay` binary from archlinuxcn.
2. **`[bootstrap.packages]`** (`mise/conf.d/20-packages.toml`):
   - Installs official packages via `pacman:`.
   - Installs AUR packages natively via `aur:` using `yay`.
3. **`[bootstrap.files]` & `[bootstrap.directories]`** (`mise/conf.d/10-system.toml`):
   - Converges `/etc/tmpfiles.d/` (ThinkPad fan & Intel GPU frequency permissions).
   - Converges `/etc/modprobe.d/thinkpad_acpi.conf`.
   - Installs Rime deployment pacman hook (`/etc/pacman.d/hooks/rime-wanxiang-deploy.hook`).
4. **`[bootstrap.services]`** (`mise/conf.d/10-system.toml`):
   - Enables and starts `bluetooth.service` and `systemd-timesyncd.service`.
5. **`[dotfiles]`** (`mise/conf.d/30-dotfiles.toml`):
   - Symlinks all user configuration files into `~/.config` and `~/.local` using `symlink-each`.
6. **`[bootstrap.user]`** (`mise/conf.d/10-system.toml`):
   - Converges the login shell to `/usr/bin/zsh`.
7. **`[bootstrap.hooks.post-dotfiles]`** (`mise/hooks/post-dotfiles.sh`):
   - Seeds initial runtime configs from `.example` templates.
   - Runs `fcitx5-theme-sync` for offline Chinese IME theming.

---

## 4. Verification & Inspection

Before or after applying, use read-only inspection commands:

```bash
mise bootstrap plan             # preview pending declarative changes
mise bootstrap status           # show aggregate resource status
mise bootstrap packages status  # verify installed official & AUR packages
mise bootstrap files status     # verify /etc files and permissions
mise bootstrap services status  # verify systemd service states
mise bootstrap dotfiles status  # verify symlink mappings
```
