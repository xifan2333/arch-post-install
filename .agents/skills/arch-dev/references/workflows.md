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

Shellcheck and shfmt match shell scripts via shebang detection (`types: sh, bash`).
Indentation is governed by `.editorconfig` (indent_size = 4 for `*.sh`); no `-i`
flag is needed.

Every step declares its `effect` (`"read"` or `"write"`) so agent runs can
use `--safe`. Builtins include effect declarations; custom steps use
`CommandSpec`.

`commit-msg` runs Commitlint (Conventional Commits). The same linters are also
available as `hk check` (read-only) and `hk fix` (auto-fix) on modified files;
add `--all` for whole-repo sweeps.

### Issue + PR Driven Development Workflow (SOP)

All feature development and bug fixes must follow the strict chronological Issue + PR workflow:
1. **Pre-Code Draft PR**: Inspect issue (`gh issue view <id>`), create branch, push empty commit, and open Draft PR with unchecked checklist (`- [ ]`).
2. **Single-Item Loop**: Implement one `- [ ]` task at a time, verify with `mise run check:plan` and `mise run check:changed`, and make a local atomic commit.
3. **Unified Push & Merge**: Push all commits, update PR checklist (`- [x]`), verify CI status, mark `gh pr ready`, and merge via `gh pr merge --squash --delete-branch`.

See [`references/issue-pr-workflow.md`](issue-pr-workflow.md) for full step-by-step SOP.

### Whole-repo checks vs per-edit workflow

Because `pre-commit` already guards all staged files on git commit, **you do not
need to run full-repo lint or format after every small file edit**.

Use scoped per-edit tasks during active development:
- `mise run check:plan` — preview which linters will run on modified files
- `mise run check:changed` — run hk checks on modified/staged/untracked files
- `mise run fix` — auto-format modified files

Use whole-repo tasks only when doing batch repository audits or cleanups:

- `mise run lint` — runs full static analysis across all files in the repository
- `mise run format` — formats all files across the repository

### Commit conventions

- Conventional Commits only: `feat:`, `fix:`, `refactor:`, `chore:`,
  `docs:`, `style:`.
- Keep commits focused. Write any user-facing text with NerdFont, ASCII, or SVG
  (this repo surfaces text to terminals, panels, and notifications).

## Complete Task Directory by Lifecycle

| Task            | Lifecycle Layer     | Location               | Purpose                                            |
| --------------- | ------------------- | ---------------------- | -------------------------------------------------- |
| `hooks`         | 1. Repo Dev         | `mise.toml`            | Install/refresh hk git hooks                       |
| `check`         | 1. Repo Dev         | `mise.toml`            | Run hk checks across modified/staged files         |
| `check:plan`    | 1. Repo Dev         | `mise.toml`            | Preview hk check execution plan without running    |
| `check:changed` | 1. Repo Dev         | `mise.toml`            | Run hk check only on modified/staged/untracked     |
| `fix`           | 1. Repo Dev         | `mise.toml`            | Auto-format modified files with hk                 |
| `lint`          | 1. Repo Dev         | `mise.toml`            | Full static analysis across all files              |
| `format`        | 1. Repo Dev         | `mise.toml`            | Full repo auto-formatting                          |
| `vm:start`      | 2. VM Sandbox       | `mise.toml`            | Start arch-basic testing VM                        |
| `vm:stop`       | 2. VM Sandbox       | `mise.toml`            | Gracefully stop testing VM                         |
| `vm:ssh`        | 2. VM Sandbox       | `mise.toml`            | SSH into testing VM                                |
| `vm:status`     | 2. VM Sandbox       | `mise.toml`            | Show testing VM status and snapshots               |
| `vm:reset`      | 2. VM Sandbox       | `mise.toml`            | Revert testing VM to clean snapshot                |

Commands may require `sudo`/`pkexec` for system-wide changes (e.g. `/etc` files).

## Atomic writes and file watching

Any daemon, collector, or background script that outputs status records
watched by status bars (such as Waybar) must write files atomically:
write to a temporary file in the same filesystem, then `os.replace` (or `mv`)
into place. This eliminates partial reads or multi-process race conditions.

## Local timezone requirement

Compute `recentDays` (rolling 7-day) and any day-level window with the **system
local calendar day** (local date parts). This keeps the "today" bucket aligned
across midnight.
