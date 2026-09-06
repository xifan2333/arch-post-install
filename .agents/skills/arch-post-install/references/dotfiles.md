# Dotfiles Editing Rules

The repo manages everything under `dotfiles/`. These become the real
`~/.config/` and `~/.local/` files via **mise bootstrap dotfiles**.

## The symlink model

`dotfiles.default_mode = "symlink"` is set in
`mise/conf.d/20-dotfiles.toml`. Two link modes are used:

| Mode           | Behavior                                                                                                           |
| -------------- | ------------------------------------------------------------------------------------------------------------------ |
| `symlink`      | The whole target is one symlink to a single source file (e.g. `.zshrc`, `starship.toml`)                           |
| `symlink-each` | A directory is recreated and each child file is linked individually, leaving files not owned by the repo untouched |

```toml
# single file
"~/.zshrc" = { source = "../../dotfiles/.zshrc" }

# whole directory, each file linked
"~/.config/hypr" = { source = "../../dotfiles/.config/hypr", mode = "symlink-each" }

# directory that excludes template/example files
"~/.config/livestream" = {
  source = "../../dotfiles/.config/livestream",
  mode = "symlink-each",
  exclude = ["*.example"],
}
```

## Edit the source, then re-apply

Make your change in `dotfiles/`, then let mise converge the symlink:

```bash
mise bootstrap dotfiles status   # inspect state
mise bootstrap dotfiles apply    # converge
```

The `~/.config/...` path is a symlink pointing into `dotfiles/`. `status` shows
each target, its mode, its source, and whether it is `applied` or `differs`
(e.g. a file exists but is not a symlink).

## `.example` templating

Sensitive or machine-specific configs are stored as `*.example` templates and
excluded from symlinking. They are seeded by the `mise/tasks/bootstrap` task on
first run only:

- `dotfiles/.config/screenrecord/*.conf.example`
- `dotfiles/.config/livestream/config.json.example` (mode 0600)
- `dotfiles/.config/dmnotifier/config.yaml.example`
- `dotfiles/.config/vinput/config.json.example` (mode 0600)
- `dotfiles/.config/qutebrowser/translate.json.example` (mode 0600)

`bootstrap` uses `install -D -m <mode>` and writes only when the file is
**missing**, so it preserves an existing local config.

## Dynamic theme link

`bootstrap` also wires the Omarchy Neovim theme into nvim:

```
$XDG_STATE_HOME/omarchy/current/theme/neovim.lua
  → ~/.config/nvim/lua/plugins/theme.lua
```

It preserves an existing unmanaged file rather than overwriting.
