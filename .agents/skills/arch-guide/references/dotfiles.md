# Dotfiles & Desktop Lifecycle Governance

The repository manages everything under `dotfiles/`. These become the real
`~/.config/` and `~/.local/` files via **mise dotfiles integration**.

---

## 1. Dual-Tier Lifecycle Model: `bootstrap` vs `dot`

Understanding the architectural boundary between `mise bootstrap` and `mise dot` is critical:

| Dimension | `mise bootstrap` (Host System Orchestrator) | `mise dot` (Home Dotfiles Deployer) |
| :--- | :--- | :--- |
| **Scope** | **Entire Machine**: `/etc` privileged files, system packages (`pacman:` / `aur:`), systemd services, user groups, and login shell | **User `$HOME` Only**: `~/.config/`, `~/.local/` symlinks and `.tera` template rendering |
| **Privilege** | Runs as user, elevates via `sudo` / `pkexec` when managing system files or services | **Pure user space**: Never requires or invokes `sudo` |
| **When to Use** | **Machine provisioning**, kernel / driver updates, adding system packages (`20-packages.toml`), modifying systemd services (`10-system.toml`) | **Daily desktop development**, tweaking UI styles (Waybar, xrwm), writing scripts, inspecting home directory drift |
| **Overhead** | Heavier: queries package databases, checks service states, and runs full lifecycle hooks | Instantaneous: microsecond symlink traversal and unified diff generation |
| **Execution Pipeline** | Master pipeline (Step 1 to 9). **`dotfiles apply` is invoked automatically as Step 4** within bootstrap. | Independent sub-pipeline: executes only file symlinking, template rendering, and `post-dotfiles` hooks. |

> **Command Deprecation Notice**: Standalone `mise dotfiles <cmd>` is deprecated upstream. Always use the canonical full form **`mise bootstrap dotfiles <cmd>`** in automated scripts or the official short alias **`mise dot <cmd>`** in interactive shells.

---

## 2. The Stow-Style Symlink Model

The mapping is declared in `mise/conf.d/30-dotfiles.toml` with `dotfiles.default_mode = "symlink-each"`:

```toml
[settings]
dotfiles.default_mode = "symlink-each"

# Stow-style single-rule dotfiles tree governance:
# Recursively walks dotfiles/ and establishes individual symlinks for all managed files,
# allowing zero-boilerplate file additions while leaving unmanaged home files untouched.
[dotfiles]
"~" = { source = "../../dotfiles", mode = "symlink-each", exclude = [
  "*.example",
  "*.tera",
  ".config/vinput/hotwords.txt",
] }

"~/.config/fontconfig/fonts.conf" = { source = "../../dotfiles/.config/fontconfig/fonts.conf.tera", mode = "template" }
"~/.config/fuzzel/fuzzel.ini" = { source = "../../dotfiles/.config/fuzzel/fuzzel.ini.tera", mode = "template" }
"~/.config/ftty/ftty.toml" = { source = "../../dotfiles/.config/ftty/ftty.toml.tera", mode = "template" }
"~/.config/waybar/style.css" = { source = "../../dotfiles/.config/waybar/style.css.tera", mode = "template" }
```

| Mode | Behavior |
| :--- | :--- |
| `symlink-each` | Recursively walks the source directory and creates individual symlinks at leaf nodes. Unmanaged neighboring files in `$HOME` remain untouched. |
| `template` | Renders dynamic Tera templates into target paths. Supported functions include `escape_html`. |

---

## 3. Daily Workflow: Edit the Source, Inspect & Apply

Always edit files inside `dotfiles/` in this repository—never edit target symlinks directly in `$HOME`.

```bash
# 1. Inspect symlink and content differences (read-only unified patch)
mise dot diff

# 2. Check aggregate deployment state (applied / differs)
mise dot status

# 3. Converge symlinks and render templates
mise dot apply

# 4. Cleanly remove managed symlinks (stateless rollback)
mise dot unapply
```

### Template Overwrite Protection
Upstream `mise dot` protects `mode = "template"` entries by default:
- Running `mise dot add` on a template target will **refuse to overwrite** the source `.tera` file, preventing rendered output from destroying dynamic template expressions or secrets. Overwrite requires explicit `--force`.
- If a rendered file in `$HOME` is manually modified, `mise dot apply` warns about the drift and identifies the source `.tera` file that should be modified instead.

---

## 4. Sensitive Configs & `.example` Templating

Sensitive or machine-specific configs are stored as `*.example` templates and excluded from direct symlinking. They are seeded by the `mise/hooks/post-dotfiles.sh` hook on first run only:

- `dotfiles/.config/screenrecord/*.conf.example`
- `dotfiles/.config/dmnotifier/config.yaml.example`
- `dotfiles/.config/vinput/config.json.example` (mode 0600)
- `dotfiles/.config/qutebrowser/translate.json.example` (mode 0600)

`mise/hooks/post-dotfiles.sh` uses `install -D -m <mode>` and writes only when the file is **missing**, preserving any existing local configurations.
