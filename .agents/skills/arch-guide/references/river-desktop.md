# River 0.4+ Suckless Desktop Environment

This reference documents the River 0.4+ desktop architecture, component boundaries, and daily operation.

---

## 1. Compositor vs. Window Manager Separation

River 0.4+ is a non-monolithic Wayland compositor:
- **`river` (Compositor)**: Strictly responsible for KMS/DRM rendering, display outputs, Wayland server, and protocol extensions (`river -c xrwm`). It has NO built-in window tiling logic and does NOT provide `riverctl`.
- **`xrwm` (Window Manager Client)**: An independent dedicated window manager implementing `river-window-management-v1`. It controls window layouts, tiling policy, window borders, and keybindings. If the WM crashes, client applications remain running.
- **`~/.config/xrwm/init`**: The session startup executable. It initializes desktop layout, borders, window rules (`~/.config/xrwm/rules`), keybindings (`~/.config/xrwm/bindings`), and background services (`~/.config/xrwm/autostart`).

---

## 2. Desktop Component Stack

| Component | Software | Role & Philosophy |
| :--- | :--- | :--- |
| **Compositor** | `river` (0.4.8+) | Zig-based, wlroots 0.20, frame-perfect |
| **Window Manager** | `xrwm` (AUR `xrwm-bin`) | Dedicated Wayland tiling WM client (`dotfiles/.config/xrwm/`), dwm-inspired tiling (master-stack), lightweight, low memory |
| **Terminal** | `foot` | Millisecond cold boot, Wayland-native, < 10 MB base memory |
| **Launcher / Menu** | `fuzzel` / `bemenu` | Dynamic stdin/stdout pipe menu, instant launch |
| **Status Bar** | `waybar` (or layer bar) | Pure presentation reading `$XDG_RUNTIME_DIR/state/*.json` |
| **Wallpaper** | `wbg` | Single C binary, presentation-time Wayland background |
| **Notification** | `fnott` / `mako` | Minimalist notification client |
| **Locker / Idle** | `waylock` + `swayidle` | PAM-based lightweight locker |
| **IME** | `fcitx5` + `rime-wanxiang` | 100% offline Xiaohe Double Pinyin, auto-deployed |

---

## 3. Collector / Display Separation (Unix Philosophy)

To ensure the UI thread never freezes or stutters:
1. **Collectors** (`dotfiles/.local/bin/`): Polling scripts and hardware monitors (ThinkPad fan, Intel GPU frequency, livestream stats, quota tracking) gather data in the background and write standard JSON files atomically to `$XDG_RUNTIME_DIR/state/*.json`.
2. **Display** (`waybar` / panel): Pure presentation. Components only read the JSON state reactively. They never perform heavy compute, blocking I/O, or network polling in the UI thread.

---

## 4. Session Launch (No Display Manager)

The declarative system service
[`arch-seamless-login.service`](../../../../mise/systemd/system/arch-seamless-login.service)
starts the TTY1 graphical session through UWSM, without a display manager or login-shell launch hook:

```ini
ExecStart=/usr/bin/uwsm start -- river -c xrwm
```

UWSM owns the graphical session's systemd user units and activation environment.
`dotfiles/.config/xrwm/init` calls `uwsm finalize` as part of session initialization.

Application launch and lifecycle changes must follow
[`principles.md` §1.4](../../arch-dev/references/principles.md): independent desktop
applications launch through `uwsm app`, graphical background services follow the
session lifetime, and native systemd/D-Bus services retain their existing owners.
Helpers inherit the application unit. Reload and stop operations use the native
application interface or the correct unit and process target. Missing required
UWSM is an error; direct-launch fallback is forbidden.

This is the required architecture. Existing direct-launch entrypoints must be
migrated when their lifecycle is changed; the policy does not imply that all
legacy entrypoints already conform.
