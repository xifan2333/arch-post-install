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
- Plugin reload: saving a file hot-reloads; force with
  `omarchy restart shell` or `omarchy-shell shell rescanPlugins`

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
