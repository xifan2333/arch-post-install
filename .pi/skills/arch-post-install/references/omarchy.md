# Omarchy Desktop Rules

Omarchy is the desktop layer (Hyprland + Quickshell shell). This repo manages the
user-facing customization; the Omarchy package provides the system layer.

## Where changes live

Make all desktop customization under `dotfiles/`:

- `dotfiles/.config/omarchy/` — shell, themes, hooks, plugins
- `dotfiles/.config/hypr/` — Hyprland config
- `dotfiles/.config/<terminal>/` — terminal configs

Reference the Omarchy system source freely for commands, defaults, and examples
(it lives at `/usr/share/omarchy/` and is managed by the omarchy package).
Your own changes go under `dotfiles/`.

## Hyprland config + validation loop

User Hyprland config is Lua, loaded after Omarchy defaults:

```
dotfiles/.config/hypr/
├── hyprland.lua       # main config
├── bindings.lua       # keybindings
├── monitors.lua       # display config
├── input.lua          # keyboard/mouse
├── looknfeel.lua      # gaps, borders, animations
├── autostart.lua      # startup apps
├── hyprsunset.conf    # night light (separate process)
└── xdph.conf          # screen-sharing portal (separate process)
```

After any `*.lua` Hyprland change, validate with:

```bash
hyprctl reload
hyprctl configerrors
```

Fix any reported errors and re-run until clean. The two `.conf` files are read
by separate processes, so `hyprctl` neither applies nor validates them — use
`omarchy restart hyprsunset` for night light.

### Rebinding keys

To re-bind an existing key:

1. Check current bindings: `omarchy menu keybindings --print`
2. Add `hl.unbind(...)` before the new `o.bind(...)` for the same key
3. Mention to the user what the key previously did.

## Omarchy shell & plugins

- Bar layout / widgets: `dotfiles/.config/omarchy/shell.json`
- User plugins: `dotfiles/.config/omarchy/plugins/xifan.*`

### Plugin development & reload commands

Omarchy shell runs inside a single Quickshell process (`omarchy-shell`). During
plugin development, use the following reload mechanisms:

1. **Automatic hot-reload (default)**: Saving any file under `dotfiles/.config/omarchy/plugins/`
   or editing `shell.json` triggers an automatic hot-reload by the shell watcher.
2. **Rescan plugins (soft reload, fast & seamless)**:
   ```bash
   omarchy-shell shell rescanPlugins
   ```
   Sends an IPC signal to the running shell to re-scan and instantiate updated plugin code without killing the shell process.
3. **Full shell restart (when state or C++ services need a clean slate)**:
   ```bash
   omarchy restart shell
   ```
   Smoothly restarts the entire `omarchy-shell` / Quickshell daemon.

### Inspecting shell & plugin logs

To monitor QML runtime warnings, binding errors, or debug output:

```bash
journalctl --user -b -n 50 --no-pager | grep -iE "quickshell|omarchy"
# or follow live:
journalctl --user -b -f
```

### Plugin naming

- The `omarchy.*` namespace is reserved for first-party built-ins; the
  `PluginRegistry` rejects any third-party id starting with `omarchy.`.
- User plugins follow `<username>.<plugin-id>` (e.g. `xifan.agents`,
  `xifan.indicators`, `xifan.overlay-captions`).
- Clone a built-in widget with `omarchy plugin clone omarchy.<id>`; the copy
  lands in `~/.config/omarchy/plugins/<username>.<id>/` and its `manifest.json`
  records `omarchy.clonedFrom`.
- A plugin directory defines its type via `kinds` (e.g. `bar-widget`,
  `overlay`, `service`) and its QML entry via `entryPoints` in `manifest.json`.

### IPC (host-to-widget routing)

- Bar widgets extend `BarWidget.qml`, which injects `bar`, `moduleName`, and
  `settings`. `moduleName` is the widget's canonical id — the host uses it to
  look up settings and to disambiguate inline IPC routes.
- A widget sets `ipcTarget` (the route it owns) and `manageIpc` in its QML.
- Use `BarWidget.broadcast(method)` to run a method on every live instance of
  the same `moduleName` (one per monitor), so a refresh reaches all surfaces.

### Collector / display separation

- Build the QML layer as pure display: read state via
  `FileView { watchChanges: true }` from `$XDG_STATE_HOME/omarchy/` JSON, and
  keep network/API work in the collector.
- Have collectors talk to external tools via standard `bin` resolution (see
  workflows.md) and write state files atomically (write temp, then `os.replace`).

## Omarchy Desktop Skill Index

For deep-dive topics provided by the system's `omarchy` skill, refer to
`~/.pi/agent/skills/omarchy/`:

| Topic | File | Covers |
| ----- | ---- | ------ |
| **Hyprland** | `hyprland.md` | Keybindings, monitors, window rules, layer rules, animations |
| **Plugins & Bar** | `plugins.md` | Status bar layout, widgets, cloning plugins, idle/lock behavior |
| **Theming** | `theming.md` | Themes, colors.toml, shell.toml overrides, backgrounds, fonts |
| **Hooks** | `hooks.md` | Event automation hooks (`theme-set`, `post-install`) |
| **Capture** | `capture.md` | Screenshots, screen recording, OCR text capture |
| **Contributing** | `contributing.md` | Diagnostics and reporting upstream Omarchy bugs |

## Command discovery

Prefer the `omarchy <group> <action>` CLI form — it is stable and
self-documenting:

```bash
omarchy commands
omarchy theme --help
omarchy restart shell    # restart the shell
omarchy refresh shell    # reload shell config
```

## Privilege escalation

For privileged commands: use `sudo` when a terminal is available for the
password prompt, or `pkexec` when it is not (agent/background). Follow the
elevation rules the underlying command already uses.
