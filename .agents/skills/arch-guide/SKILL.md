---
name: arch-guide
description: >
  REQUIRED when provisioning a machine, restoring the desktop environment after
  archinstall, managing system packages, configuring system services, or using
  the River suckless desktop environment. Use whenever running mise bootstrap,
  declaring official pacman or AUR packages in mise/conf.d/20-packages.toml,
  configuring system services or privileged files in 10-system.toml, mapping
  dotfiles in 30-dotfiles.toml, configuring River window manager, Fcitx5 + Rime
  Chinese IME, ThinkPad hardware controls, or audio/multimedia. Trigger on: 恢复桌面,
  archinstall 装机后, 安装软件/添加包, 配置系统服务, River桌面使用, 快捷键说明,
  中文输入法, dotfiles管理.
---

# Arch Post-Install: Machine Setup & Desktop Guide

This skill provides operational guidance for restoring a fully configured Arch Linux + River desktop workstation on a newly installed machine and managing system packages, services, and dotfiles.

## Start Here

Read the matching reference before modifying system configuration:

- [`references/post-install-guide.md`](references/post-install-guide.md) — complete step-by-step restoration from minimal archinstall to running desktop.
- [`references/river-desktop.md`](references/river-desktop.md) — River 0.4+ Compositor + WM architecture, layer shell, and collector/display separation.
- [`references/dotfiles.md`](references/dotfiles.md) — editing dotfiles safely (symlink model, source-over-target, `symlink-each`).
- [`references/related-projects.md`](references/related-projects.md) — companion tools and boundaries (`pi-quotas`, `vcam`).

## 1. One-Command Machine Provisioning

On a clean machine after `archinstall`:

```bash
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

git clone https://github.com/xifan2333/arch-post-install.git ~/Code/arch-post-install
cd ~/Code/arch-post-install

mise trust
mise bootstrap --yes
```

Log out and log back into TTY1. The environment launches `river` automatically.

## 2. Declarative Machine Configuration Cheatsheet

Always edit the declarative sources in `mise/conf.d/`:

### Adding Packages (`mise/conf.d/20-packages.toml`)

Mise natively manages official Arch packages and AUR packages side by side:

```toml
[bootstrap.packages]
# Official pacman packages
"pacman:foot" = "latest"
"pacman:pipewire" = "latest"

# AUR packages (installed automatically via yay)
"aur:karing-bin" = "latest"
"aur:wechat-appimage" = "latest"
```

Preview changes before applying:
```bash
mise bootstrap packages status
mise bootstrap plan
```

### Managing System Services (`mise/conf.d/10-system.toml`)

Declare systemd system services state directly:

```toml
[bootstrap.services.bluetooth]
state = "running"
enabled = true

[bootstrap.services.systemd-timesyncd]
state = "running"
enabled = true
```

### Managing Dotfiles (`mise/conf.d/30-dotfiles.toml`)

Map configuration directories from `dotfiles/` into `$HOME`:

```toml
[settings]
dotfiles.default_mode = "symlink"

[dotfiles]
"~/.config/foot" = { source = "../../dotfiles/.config/foot", mode = "symlink-each" }
"~/.config/river" = { source = "../../dotfiles/.config/river", mode = "symlink-each" }
```

Apply dotfile updates:
```bash
mise bootstrap dotfiles apply
```

## 3. Chinese Input Method (Fcitx5 + Rime)

- Schema: **Wanxiang Flypy (万象小鹤双拼)** from `archlinuxcn/rime-wanxiang-flypy`.
- Auto-Deployment: A pacman hook (`/etc/pacman.d/hooks/rime-wanxiang-deploy.hook`) automatically redeploys Rime when dictionary or schema packages update.
- Theme: Standalone custom theme synchronized via `arch theme sync fcitx5`.

## 4. Hardware Controls (ThinkPad & Intel GPU)

Non-root write permissions are granted via `/etc/tmpfiles.d/`:
- **ThinkPad Fan**: `/proc/acpi/ibm/fan` controlled via `arch hw fan [status|auto|0-7]`.
- **Intel GPU Frequencies**: Controlled via `arch hw gpu [status|auto|max]`.

## 5. Universal Desktop CLI (`arch`)

All desktop utilities can be invoked via `arch <group> <action>` or `arch-<group>-<action>`:
- `arch theme set <name>` / `arch theme menu`: switch desktop themes.
- `arch hw fan` / `arch hw gpu`: inspect/control hardware.
- `arch cap ocr`: capture screen region and copy recognized text.
- `arch i18n get <key>`: query localized strings.
- `arch font sync`: sync pixel fonts from GitHub releases.
- `arch live push [start|stop|status]`: control live streaming pipeline.
