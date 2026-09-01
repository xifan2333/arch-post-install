# Workflows, Git, and Development Conventions

## Git + Lefthook

This repo uses **Lefthook** for fast staged-file checks. Config is in
`lefthook.yml`; install with `mise run hooks` (or `lefthook install`).

`pre-commit` runs in parallel on **staged files only** (`{staged_files}`), so
commits are near-instant (0.05s) and validate Python, Shell, Lua, TOML, JSON,
YAML, and QML files automatically at commit time.

Coverage:

| File type                  | Tools                 |
| -------------------------- | --------------------- |
| `*.py`                     | Ruff (check + format) |
| `*.{sh,bash}`              | ShellCheck + Shfmt    |
| `**/mise/tasks/*` (no ext) | ShellCheck + Shfmt    |
| `*.lua`                    | Stylua + luac         |
| `*.toml`                   | Taplo (format + lint) |
| `*.{json,jsonc,yaml,yml}`  | Prettier              |
| `*.qml`                    | qmllint               |

`commit-msg` runs Commitlint (Conventional Commits).

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
| `hooks`     | 1. Repo Dev         | `mise.toml`            | Install/refresh Lefthook git hooks                 |
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
