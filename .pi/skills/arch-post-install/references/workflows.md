# Workflows, Git, and Development Conventions

## Git + hk

This repo uses **hk** for fast staged-file checks. Config is in
`hk.pkl`; install with `mise run hooks` (or `hk install`).

`pre-commit` runs in parallel on **staged files only** and auto-fixes + re-stages
files that fail a read-only check (`check_first`), so commits stay fast and
validate Python, Shell, Lua, TOML, JSON, YAML, and QML files automatically at
commit time. Unstaged changes are stashed (`stash = "git"`) while fixes apply
and restored afterwards, so partially staged edits are never swept into the
commit. `fail_fast = false` keeps every step independent. Bypass hooks for one
command with `HK=0 git commit`.

Coverage:

| File type                  | Tools (hk Builtins where available) |
| -------------------------- | ----------------------------------- |
| `*.py`                     | Builtins.ruff + Builtins.ruff_format |
| `*.{sh,bash}` + shebang   | Builtins.shellcheck + Builtins.shfmt |
| `*.lua`                    | Builtins.stylua + luac (CommandSpec) |
| `*.toml`                   | Builtins.taplo (--no-schema) + Builtins.taplo_format |
| `*.{json,jsonc,yaml,yml}`  | Builtins.prettier |
| `*.zsh`                    | zsh -n + shfmt (CommandSpec)        |
| `*.js`                     | oxlint (CommandSpec) |
| `*.qml`                    | qmllint (CommandSpec) |

Shellcheck and shfmt match extensionless `mise/tasks/*` scripts via shebang
detection (`types: sh, bash`). Indentation is governed by `.editorconfig`
(indent_size = 4 for `*.sh` and `mise/tasks/*`); no `-i` flag is needed.

Every step declares its `effect` (`"read"` or `"write"`) so agent runs can
use `--safe`. Builtins include effect declarations; custom steps use
`CommandSpec`.

`commit-msg` runs Commitlint (Conventional Commits). The same linters are also
available as `hk check` (read-only) and `hk fix` (auto-fix) on modified files;
add `--all` for whole-repo sweeps.

### Whole-repo checks vs per-edit workflow

Because `pre-commit` already guards all staged files on git commit, **you do not
need to run full-repo lint or format after every small file edit**.

Use these tasks only when doing whole-repository audits or batch cleanups:

- `mise run lint` — runs full static analysis across all files in the repository
- `mise run format` — formats all files across the repository

### Commit conventions

- Conventional Commits only: `feat:`, `fix:`, `refactor:`, `chore:`,
  `docs:`, `style:`.
- Keep commits focused. Write any user-facing text with NerdFont, ASCII, or SVG
  (this repo surfaces text to terminals, panels, and notifications).

## Complete Task Directory by Lifecycle

| Task        | Lifecycle Layer     | Location               | Purpose                                            |
| ----------- | ------------------- | ---------------------- | -------------------------------------------------- |
| `hooks`     | 1. Repo Dev         | `mise.toml`            | Install/refresh hk git hooks                 |
| `lint`      | 1. Repo Dev         | `mise.toml`            | Full static analysis across all files              |
| `format`    | 1. Repo Dev         | `mise.toml`            | Full repo auto-formatting                          |
| `bootstrap` | 2. System Bootstrap | `mise/tasks/bootstrap` | Seed `.example` configs + wire nvim theme          |
| `hardware`  | 2. System Bootstrap | `mise/tasks/hardware`  | Apply ThinkPad fan control + Intel GPU permissions |
| `aur`       | 2. System Bootstrap | `mise/tasks/aur`       | Install AUR-only packages via yay                  |
| `wps`       | 2. System Bootstrap | `mise/tasks/wps`       | Force WPS multi-component mode                     |
| `fonts`     | 3. Asset Maint      | `mise/tasks/fonts`     | Update pixel fonts from GitHub releases            |

Commands may require `sudo`/`pkexec` for system-wide changes (e.g. AUR, `/etc`
hooks). Follow the privilege rules in `omarchy.md`.

## Atomic writes and file watching

Any daemon, collector, or background script that outputs status records
watched by Quickshell / Omarchy plugins must write files atomically:
write to a temporary file in the same filesystem, then `os.replace` (or `mv`)
into place. This eliminates partial reads or multi-process race conditions.

## Local timezone requirement

Compute `recentDays` (rolling 7-day) and any day-level window with the **system
local calendar day** (local date parts). This keeps the "today" bucket aligned
across midnight.
