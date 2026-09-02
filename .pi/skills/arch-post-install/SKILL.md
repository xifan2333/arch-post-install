---
name: arch-post-install
description: >
  REQUIRED for maintaining and customizing this personal Arch Linux + Omarchy
  system setup repository. Use whenever editing the mise configuration
  (mise.toml, mise/conf.d/*, mise/tasks/*), managing system packages or
  bootstrapping a machine, modifying files under dotfiles/ (~/.config/,
  ~/.local/), developing Omarchy shell plugins (xifan.*), adjusting Hyprland
  configs (*.lua), or running system setup tasks (aur, bootstrap, fonts, wps).
  Also use before committing changes so repo conventions are upheld.
---

# Arch Post-Install & Omarchy System Kit

This repository is the **single source of truth** for this personal Arch Linux

- Omarchy desktop system. It is a declarative infrastructure kit: every change
  flows through the documented mechanisms below.

## Start here

Read the matching reference before editing:

- [`references/mise-structure.md`](references/mise-structure.md) — the two-layer
  mise configuration and where each concern belongs.
- [`references/omarchy.md`](references/omarchy.md) — desktop rules: system dir
  boundaries, Hyprland validation loop, shell plugins, panels, and plugin reload commands.
- [`references/dotfiles.md`](references/dotfiles.md) — editing dotfiles safely
  (symlink model, `*.example` templating, source-over-target).
- [`references/workflows.md`](references/workflows.md) — git/hk
  conventions, maintenance tasks, and repo development workflows.
- [`references/related-projects.md`](references/related-projects.md) — index and
  integration boundaries for standalone companion projects (`pi-quotas`, `vcam`, etc.).
- **Omarchy Skill** (`omarchy`) — for system-wide desktop guides (Hyprland,
  themes, hooks, capture, built-in shell plugins), refer to the bundled
  Omarchy skill (`~/.pi/agent/skills/omarchy/SKILL.md`).

## Where edits go

Put your change in the right home. This table answers "what do I edit?":

| Goal                                        | Edit                            |
| ------------------------------------------- | ------------------------------- |
| Add/change a repo linter or dev tool        | `mise.toml` → `[tools]`         |
| Add/update repo check or format tasks       | `mise.toml` → `[tasks.*]`       |
| Install a system pacman package             | `mise/conf.d/10-bootstrap.toml` |
| Add a privileged file/dir or pacman hook    | `mise/conf.d/10-bootstrap.toml` |
| Map a dotfile into `~/.config` / `~/.local` | `mise/conf.d/20-dotfiles.toml`  |
| Add an AUR-only package                     | `mise/tasks/aur`                |
| Change system bootstrap initialization      | `mise/tasks/bootstrap`          |
| Update pixel fonts download automation      | `mise/tasks/fonts`              |
| Change WPS window component mode task       | `mise/tasks/wps`                |
| Adjust Hyprland keybind/monitor/windows     | `dotfiles/.config/hypr/*.lua`   |
| Build/modify an Omarchy panel or plugin     | `dotfiles/.config/omarchy/`     |

## Workflow

1. **Separate the three task & config layers.** Repo dev tooling (linters,
   formatters, `hooks`/`check`/`format` tasks) lives in root `mise.toml`. Machine
   bootstrap (pacman packages, privileged files, dotfiles, AUR tasks) lives under
   `mise/`. Asset maintenance (`fonts`) lives in `mise/tasks/`. Keep them apart.

2. **Edit `dotfiles/` source.** The `~/.config` and `~/.local` targets are
   symlinks managed by mise bootstrap; the source of truth lives in
   `dotfiles/`. Make your change there.

3. **Place AUR-only packages in `mise/tasks/aur`.** Mise's `pacman:` manager
   covers official repos. AUR packages need an AUR helper and build from source,
   so they belong in the `aur` task (driven by `yay`), gated with `pacman -Q`.

4. **Validate Hyprland Lua changes.** After editing any `dotfiles/.config/hypr/*.lua`,
   run `hyprctl reload` then `hyprctl configerrors`, and fix until clean.

5. **Keep tasks idempotent.** Mise bootstrap converges — re-running is safe and
   skips already-correct state. Write `mise/tasks/*` accordingly.

6. **Use read-only checks before applying.** When unsure, verify first:
   `mise bootstrap packages status`, `mise bootstrap files status`,
   `mise bootstrap dotfiles status`, `mise tasks validate`. Apply only after
   the plan looks right.

7. **Write text with NerdFont, ASCII, or SVG.** This repo surfaces text to many
   places (terminals, panels, notifications), so prefer those over emoji.

8. **Use the local calendar day for date math.** Any date/window calc uses the
   system local timezone (local date parts), so the "today" bucket stays aligned
   across midnight.

9. **Commit with Conventional Commits.** `feat:`, `fix:`, `refactor:`,
   `chore:`, `docs:`, `style:`. The pre-commit hook (hk) automatically runs
   linter and formatter on staged files. Whole-repo `mise run lint` and `mise run format`
   are for repo-wide verification, not required after every micro edit.

## Task commands by lifecycle

### 1. Repo Development & Quality Layer (in `mise.toml`)

```bash
mise run hooks      # install/refresh hk git hooks
mise run lint       # run full static analysis across the entire repository
mise run format     # format all Python, Shell, Lua, TOML, and JSON/YAML files
```

### 2. System Bootstrap Layer (in `mise/tasks/`)

```bash
mise run bootstrap  # seed .example configs + wire nvim theme (depends on aur, wps, hardware)
mise run hardware   # apply ThinkPad fan control permissions & rebuild initramfs
mise run aur        # install AUR-only packages via yay
mise run wps        # force WPS multi-component mode
```

### 3. Asset & Maintenance Layer (in `mise/tasks/`)

```bash
mise run fonts      # update pixel fonts from GitHub releases
```

For privileged (`/etc`, root-owned) changes, use `sudo` when a terminal is
available for the password, otherwise `pkexec` (agent/background).

## Related Standalone Projects

For detailed architecture boundaries, see [`references/related-projects.md`](references/related-projects.md):

- **`pi-quotas`** (`/home/xifan/Code/pi-quotas`): Standalone Pi CLI/plugin for AI token quota tracking. Consumed by `xifan.agents` bar plugin (`collect_pi_usage.py`).
- **`vcam`** (`/home/xifan/Code/vcam`): Android Camera2 Hook app for low-latency live streaming over LAN SRT. Driven by `livestream` / `livestream-service` on Linux.
