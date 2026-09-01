# Workflows, Git, and the Pi-Quotas Panel Collector

## Git + Lefthook

This repo uses **Lefthook** for fast staged-file checks. Config is in
`lefthook.yml`; install with `mise run hooks` (or `lefthook install`).

`pre-commit` runs in parallel on **staged files only** (`{staged_files}`), so
commits are near-instant (0.05s). Coverage:

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

To run whole-repo checks at any time:

- `mise run lint` — runs full static analysis across all files
- `mise run format` — formats all files across the repository

### Commit conventions

- Conventional Commits only: `feat:`, `fix:`, `refactor:`, `chore:`,
  `docs:`, `style:`.
- Keep commits focused. Write any user-facing text with NerdFont, ASCII, or SVG
  (this repo surfaces text to terminals, panels, and notifications).

## Complete Task Directory by Lifecycle

| Task        | Lifecycle Layer     | Location               | Purpose                                   |
| ----------- | ------------------- | ---------------------- | ----------------------------------------- |
| `hooks`     | 1. Repo Dev         | `mise.toml`            | Install/refresh Lefthook git hooks        |
| `check`     | 1. Repo Dev         | `mise.toml`            | Full static analysis across all files     |
| `format`    | 1. Repo Dev         | `mise.toml`            | Full repo auto-formatting                 |
| `bootstrap` | 2. System Bootstrap | `mise/tasks/bootstrap` | Seed `.example` configs + wire nvim theme |
| `aur`       | 2. System Bootstrap | `mise/tasks/aur`       | Install AUR-only packages via yay         |
| `wps`       | 2. System Bootstrap | `mise/tasks/wps`       | Force WPS multi-component mode            |
| `fonts`     | 3. Asset Maint      | `mise/tasks/fonts`     | Update pixel fonts from GitHub releases   |

Commands may require `sudo`/`pkexec` for system-wide changes (e.g. AUR, `/etc`
hooks). Follow the privilege rules in `omarchy.md`.

## Pi-Quotas panel collector

The Omarchy **agents panel** (`xifan.agents`) shows model quota + usage. Its
collector is `dotfiles/.config/omarchy/plugins/xifan.agents/collect_pi_usage.py`.

Flow:

```
Quickshell (Main.qml)                   # triggers on start / 15m / manual
  └─ collect_pi_usage.py                # Omarchy-only writer
       ├─ find pi-quotas binary (bin dir)   # ~/.pi/agent/npm/node_modules/.bin
       ├─ run  pi-quotas --json
       └─ atomically write per-provider JSON
            ~/.local/state/omarchy/agents/usage/{provider}.json
  └─ Panel.qml / FileView              # pure display, watchChanges: true
```

### Finding the pi-quotas binary

Resolve the CLI via standard `bin` discovery:

```python
pi_bin_dir = Path.home() / ".pi" / "agent" / "npm" / "node_modules" / ".bin"
search_path = f"{pi_bin_dir}:{os.environ.get('PATH', '')}"
bin_path = shutil.which("pi-quotas", path=search_path)
```

`pi-quotas` is a separately published Pi plugin (npm + GitHub). It is not part
of this repo; this repo only consumes it. The panel writes one record per
provider with `limits`, `balance`, `recentDays`, and `modelUsage`.

### Atomic write requirement

Collector writes are atomic: write to a temp file, then `os.replace` into the
target. This avoids partial reads / multi-process races when FileView watches
the directory.

## Local timezone requirement

Compute `recentDays` (rolling 7-day) and any day-level window with the **system
local calendar day** (local date parts). This keeps the "today" bucket aligned
across midnight.
