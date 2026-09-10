# River 0.4+ Suckless Desktop Environment

This reference documents the River 0.4+ desktop architecture, component boundaries, and daily operation.

---

## 1. Compositor vs. Window Manager Separation

River 0.4+ is a non-monolithic Wayland compositor:
- **`river` (Compositor)**: Strictly responsible for KMS/DRM rendering, display outputs, Wayland server, and protocol extensions. It has NO built-in window tiling logic and does NOT provide `riverctl`.
- **Window Manager (Client)**: An independent process implementing `river-window-management-v1`. It controls window layouts, tiling policy, window borders, and focus. If the WM crashes, client applications remain running.
- **`~/.config/river/init`**: The session startup executable. It acts as the process group leader, launching the window manager, output manager (`kanshi`), status bar, notification daemon, and background collectors.

---

## 2. Desktop Component Stack

| Component | Software | Role & Philosophy |
| :--- | :--- | :--- |
| **Compositor** | `river` (0.4.8+) | Zig-based, wlroots 0.20, frame-perfect |
| **Window Manager** | C/Zig River WM Client | dwm-inspired tiling (master-stack), lightweight, low memory |
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

Following Suckless frugality, this environment avoids heavy display managers (SDDM, GDM, LightDM).
Log in at the Linux console (TTY1). The shell profile (`~/.zprofile`) automatically starts River:

```sh
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec river
fi
```
