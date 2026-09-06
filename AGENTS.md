# Agent Instructions & Project Guidelines

This repository is the single source of truth for a personal Arch Linux + Omarchy desktop environment.

---

## 1. Project Structure & Edit Locations

Always edit source files within this repository. The `~/.config` and `~/.local` directories are symlinks managed by mise bootstrap.

| Goal | Target File / Directory |
| --- | --- |
| Repo dev tools & linters | `mise.toml` → `[tools]` |
| Machine packages & system hooks | `mise/conf.d/10-bootstrap.toml` |
| Dotfile symlink mappings | `mise/conf.d/20-dotfiles.toml` |
| AUR packages | `mise/tasks/aur` |
| System bootstrap logic | `mise/tasks/bootstrap` |
| Hyprland configuration | `dotfiles/.config/hypr/*.lua` |
| Omarchy shell & bar plugins | `dotfiles/.config/omarchy/plugins/` |
| Shell layout & widget settings | `dotfiles/.config/omarchy/shell.json` |
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

For the complete SOP, refer to `.agents/skills/arch-post-install/references/issue-pr-workflow.md`.

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

## 5. Omarchy Shell & Plugin Development Standards

Omarchy desktop runs inside a single long-lived Quickshell process (`omarchy-shell`).

1. **System Boundaries**:
   - `/usr/share/omarchy/` is **read-only** (managed by system package). Never modify files here.
   - User plugins live under `dotfiles/.config/omarchy/plugins/<plugin-id>/`.
2. **Namespace Isolation**:
   - `omarchy.*` is reserved for official built-ins.
   - User plugins must use `<username>.<plugin-id>` (e.g. `dotfiles/.config/omarchy/plugins/xifan.*`).
   - To customize a built-in widget, clone it with `omarchy plugin clone omarchy.<id>`.
3. **Collector / Display Separation**:
   - **QML UI**: Pure presentation. Read state reactively via `FileView { watchChanges: true }` from `$XDG_STATE_HOME/omarchy/` JSON files. Never block QML with heavy compute or network requests.
   - **Collectors / Daemons**: Heavy polling, API calls, and hardware sensors belong in separate Python/Bash scripts.
   - **Atomic Writes**: Collectors must write state files to a temporary file in the same filesystem first, then atomically replace (`os.replace` / `mv`) to prevent Quickshell from reading incomplete JSON.
4. **IPC Contract & Multi-Monitor**:
   - Summon or toggle overlays: `omarchy-shell shell summon|toggle <id> '<jsonPayload>'`.
   - Multi-monitor sync: Use `BarWidget.broadcast(method)` to refresh instances across all screens.
   - String boolean typing: IPC boolean arguments must be the literal string `"true"` (all other strings are evaluated as `false`).
5. **Configuration (`shell.json`)**:
   - Layout and widget instances are persisted flatly in `dotfiles/.config/omarchy/shell.json`.
   - Settings are inline on each entry (no nested `config:` objects). A third-party plugin is enabled if and only if its entry exists in `shell.json`.
6. **Reloading & Debugging**:
   - Prefer `omarchy restart shell` during active plugin development to guarantee clean QML/JS module caches.
   - Use `omarchy-shell shell rescanPlugins` for lightweight metadata/new plugin discovery.
   - View live runtime logs: `journalctl --user -b -f | grep -iE "quickshell|omarchy"`.

---

## 6. General Desktop & Coding Conventions

1. **Hyprland Validation**: After modifying any `dotfiles/.config/hypr/*.lua`, test configuration with `hyprctl reload` followed by `hyprctl configerrors`.
2. **Typography & Glyphs**: Prefer NerdFont glyphs, ASCII, or SVG over emoji for terminal and panel consistency.
3. **Timezone**: Compute rolling metrics (e.g. 7-day usage, daily buckets) using the system local calendar day to prevent midnight rollover drift.
4. **Commit Messages**: Follow Conventional Commits format (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `style:`).
