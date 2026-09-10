# Agent Instructions & Project Guidelines

This repository is the single source of truth for a personal Arch Linux desktop environment adhering to Suckless and Unix philosophies (see `.agents/skills/arch-dev/references/principles.md`).

---

## 1. Project Structure & Edit Locations

Always edit source files within this repository. The `~/.config` and `~/.local` directories are symlinks managed by mise bootstrap.

| Goal | Target File / Directory |
| --- | --- |
| Repo dev tools & linters | `mise.toml` → `[tools]` |
| System services, hooks & privileged files | `mise/conf.d/10-system.toml` |
| Machine packages (pacman & aur) | `mise/conf.d/20-packages.toml` |
| Dotfile symlink mappings | `mise/conf.d/30-dotfiles.toml` |
| Pre-packages bootstrap hook | `mise/hooks/pre-packages.sh` |
| Post-dotfiles runtime hook | `mise/hooks/post-dotfiles.sh` |
| Window manager & compositor | `dotfiles/.config/river/` |
| State collectors & CLI tools | `dotfiles/.local/bin/` |
| Dotfile sources | `dotfiles/` (never edit target symlinks directly) |

---

## 2. Dual-Planning Model for AI Agents

To avoid ambiguity between functional task planning and toolchain validation, agents must distinguish between two distinct planning phases:

| Phase | Concept & Terminology | Timing | Tool & Output | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Phase A** | **Task Planning**<br>*(Feature / Bugfix Breakdown)* | **Pre-development**<br>*(Before coding)* | GitHub Issue & Draft PR body (`- [ ]` checklist) | Defines *what* code/config to write, module boundaries, and task sequencing. |
| **Phase B** | **Quality Gate Pre-check**<br>*(hk --plan)* | **Post-edit**<br>*(Before committing)* | `mise run check:plan`<br>*(or `hk run check --safe --plan`)* | Previews *which* linters/formatters will run and their effects on edited files. |

---

## 3. Strict Chronological Development Workflow (Issue + Draft PR)

All coding agents must strictly operate within this closed-loop chronological lifecycle:

```
+------------------------------------------------------------------------+
| 1. Pre-Code Initialization (MANDATORY BEFORE ANY CODE IS WRITTEN)       |
|    gh issue view <id>                                                  |
|    git checkout -b <type>/issue-<id>-<name>                            |
|    git commit --allow-empty -m "chore: initialize draft pr for #<id>"   |
|    git push -u origin <type>/issue-<id>-<name>                         |
|    gh pr create --draft (ALL tasks unchecked: - [ ])                   |
+-----------------------------------+------------------------------------+
                                    |
                +-------------------v-------------------+
                | 2. Single-Item Focused Development    |
                |    Only implement the first - [ ]     |
                +-------------------+-------------------+
                                    |
                +-------------------v-------------------+
                | 3. Local Quality Gate & Pre-check     |
                |    mise run check:plan (preview steps)|
                |    mise run check:changed             |
                |    mise run fix (if needed)           |
                |    Domain validations (Hypr/Omarchy)  |
                +-------------------+-------------------+
                                    |
                +-------------------v-------------------+
                | 4. Local Atomic Commit                |
                |    git add <files>                    |
                |    git commit -m "<type>(<scope>): ..."|
                |    (Keep commit local)                |
                +-------------------+-------------------+
                                    | (Remaining tasks?)
                                    +-------- Yes -------+
                                    | No                 |
+-----------------------------------v-------------------+|
| 5. Unified Push, Checks & Merge                       ||
|    git push origin <branch>                           ||
|    gh pr edit --body (check all - [x])                ||
|    gh pr checks (verify PR CI status)                 ||
|    gh pr ready (mark as ready for review)             ||
|    gh pr merge --squash --delete-branch               ||
+-------------------------------------------------------+|
                                    ^                    |
                                    +--------------------+
```

For the complete SOP, refer to `.agents/skills/arch-dev/references/issue-pr-workflow.md`.

---

## 4. Code Quality & `hk` Workflow

This repository uses **hk** (`hk.pkl`) for git hooks and code quality checks.

- **Scoped Checks**: Inspect and scope checks to modified files. Use `mise run check:plan` to preview, and `mise run check:changed` to run checks on changed/untracked files.
- **Auto-Fixing**: Use `mise run fix` (or `hk fix`) to automatically format and fix style violations.
- **Pre-commit Automation**: `pre-commit` runs in parallel on staged files only and auto-formats / fixes failing files before re-staging them.
- **Avoid Micro Full-Sweeps**: Do not run full-repo lint (`mise run lint`) on every small file change; rely on scoped `mise run check:changed`. Full sweeps are for batch audits.
- **Review Diff**: Always review the git diff produced by any auto-fix step before committing.

Supported formatters and linters:
- **Python**: `ruff`, `ruff format`
- **Shell**: `shellcheck`, `shfmt` (4-space indent via `.editorconfig`)
- **Lua**: `stylua`, `luac`
- **TOML**: `taplo` (with `--no-schema`)
- **JSON / YAML**: `prettier`
- **JavaScript**: `oxlint`
- **QML**: `qmllint`
- **Zsh**: `zsh -n` (syntax check), `shfmt` (format)

---

## 5. System Architecture & Suckless Standards

This system follows the principles documented in `.agents/skills/arch-dev/references/principles.md`:

1. **Self-Containment & Zero External Framework Lock-in**:
   - Never reference `/usr/share/omarchy/` or rely on proprietary distribution hooks.
   - All desktop logic, keybindings, and theme pipelines must reside self-contained within this repository.
2. **Collector / Display Separation**:
   - **Display UI**: Pure presentation (e.g. Waybar, minimal river client). Read state reactively from `$XDG_RUNTIME_DIR/state/` JSON files. Never perform heavy compute, blocking I/O, or network polling in UI components.
   - **Collectors / Daemons**: Polling, sensor queries, hardware state, and API sync belong in standalone scripts under `dotfiles/.local/bin/` managed by user timers or background services.
   - **Atomic Writes**: Collectors must write state files to a temporary file on the same filesystem first, then atomically replace (`os.replace` / `mv`) to guarantee that consumers never read incomplete or corrupted state.
3. **Suckless Frugality**:
   - Favor minimal C / Zig / POSIX Shell components over bloated GUI wrappers or multi-megabyte daemon frameworks.
   - Mechanism over policy: The window manager and shell should remain strictly within the user's cognitive control.

---

## 6. General Desktop & Coding Conventions

1. **Typography & Glyphs**: Prefer NerdFont glyphs, ASCII, or SVG over emoji for terminal and panel consistency.
2. **Timezone**: Compute rolling metrics (e.g. 7-day usage, daily buckets) using the system local calendar day to prevent midnight rollover drift.
3. **Commit Messages**: Follow Conventional Commits format (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `style:`).
