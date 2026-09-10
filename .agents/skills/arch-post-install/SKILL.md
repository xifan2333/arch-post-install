---
name: arch-post-install
description: >
  REQUIRED for maintaining and customizing this personal Arch Linux + River
  desktop repository. Use whenever editing the mise configuration
  (mise.toml, mise/conf.d/*, mise/hooks/*), managing system packages or
  bootstrapping a machine, modifying files under dotfiles/ (~/.config/,
  ~/.local/), configuring River window manager, following the Issue + Draft PR
  development workflow (SOP), or managing the VM testing sandbox (vm:*).
  Trigger also on requests such as 根据 issue 拆解开发、开 PR/提 PR、Draft PR 工作流、
  单任务循环提交、代码体检与格式化自检. Also use before committing changes so
  repo conventions are upheld.
---

# Arch Post-Install & Omarchy System Kit

This repository is the **single source of truth** for this personal Arch Linux

- Omarchy desktop system. It is a declarative infrastructure kit: every change
  flows through the documented mechanisms below.

## Start here

Read the matching reference before editing:

- [`references/issue-pr-workflow.md`](references/issue-pr-workflow.md) — mandatory
  Issue + Draft PR driven development workflow (SOP), Dual-Planning model, single-item loop, and merge.
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

## Issue + PR Driven Development Workflow (SOP)

Development must follow a strict, chronological **Pre-Code Draft PR -> Single-Item Loop -> Merge** lifecycle:

1. **Dual-Planning Model**:
   - **Phase A: Task Planning (Pre-development - BEFORE CODING)**: Issue breakdown and opening Draft PR with an unchecked `- [ ]` checklist.
   - **Phase B: Quality Gate Pre-check (Post-edit - AFTER EDIT)**: Previewing linters via `mise run check:plan`.
2. **Chronological Steps**:
   - `gh issue view <id>` -> checkout branch `<type>/issue-<id>-<name>` -> empty commit -> push -> `gh pr create --draft` (all `- [ ]`).
   - For each `- [ ]` task in sequence: implement **only** that task -> run `mise run check:plan` & `mise run check:changed` -> local atomic commit.
   - Finalize: `git push origin <branch>` -> `gh pr edit --body` (check `- [x]`) -> `gh pr checks` -> `gh pr ready` -> `gh pr merge --squash --delete-branch`.

For full details, see [`references/issue-pr-workflow.md`](references/issue-pr-workflow.md).

## Where edits go

Put your change in the right home. This table answers "what do I edit?":

| Goal                                        | Edit                            |
| ------------------------------------------- | ------------------------------- |
| Add/change a repo linter or dev tool        | `mise.toml` → `[tools]`         |
| Add/update repo check or format tasks       | `mise.toml` → `[tasks.*]`       |
| Configure system services or privileged file| `mise/conf.d/10-system.toml`    |
| Add a system package (pacman or aur)        | `mise/conf.d/20-packages.toml`  |
| Map a dotfile into `~/.config` / `~/.local` | `mise/conf.d/30-dotfiles.toml`  |
| Update pre-packages setup hook              | `mise/hooks/pre-packages.sh`    |
| Update post-dotfiles runtime hook           | `mise/hooks/post-dotfiles.sh`   |
| Manage window manager & compositor          | `dotfiles/.config/river/`       |
| Manage state collectors & CLI tools         | `dotfiles/.local/bin/`          |

## Workflow

1. **Pure Declarative Bootstrap (No Task Mixing).** Machine provisioning is
   driven 100% through declarative configuration (`mise/conf.d/*.toml`) and
   lifecycle hooks (`mise/hooks/*.sh`). The task system (`[tasks.*]` in root
   `mise.toml`) is strictly reserved for repository development tooling (linters,
   formatters) and VM sandbox management (`vm:*`).

2. **Edit `dotfiles/` source.** The `~/.config` and `~/.local` targets are
   symlinks managed by mise bootstrap; the source of truth lives in
   `dotfiles/`. Make your change there.

3. **Declare AUR packages natively in `20-packages.toml`.** Mise supports
   `aur:` package declarations directly in `[bootstrap.packages]`. The
   `pre-packages.sh` hook ensures `yay` and `base-devel` are available before
   package installation runs.

4. **Validate River configs.** Keep river configurations minimal, modular, and
   compliant with river 0.4+ protocol separation.

5. **Keep bootstrap idempotent.** Mise bootstrap converges — re-running is safe
   and skips already-correct state.

6. **Use read-only checks before applying.** When unsure, verify first:
   `mise bootstrap packages status`, `mise bootstrap files status`,
   `mise bootstrap services status`, `mise bootstrap dotfiles status`. Apply only
   after the plan looks right.

7. **Write text with NerdFont, ASCII, or SVG.** This repo surfaces text to many
   places (terminals, panels, notifications), so prefer those over emoji.

8. **Use the local calendar day for date math.** Any date/window calc uses the
   system local timezone (local date parts), so the "today" bucket stays aligned
   across midnight.

9. **Commit with Conventional Commits.** `feat:`, `fix:`, `refactor:`,
   `chore:`, `docs:`, `style:`. The pre-commit hook (hk) automatically runs
   linter and formatter on staged files. Whole-repo `mise run lint` and `mise run format`
   are for repo-wide verification, not required after every micro edit.

## Commands by lifecycle

### 1. Repo Development & Quality Layer (in `mise.toml`)

```bash
mise run hooks          # install/refresh hk git hooks
mise run check:plan     # preview which linters will run on modified files
mise run check:changed  # run hk checks across modified/staged/untracked files
mise run fix            # auto-format modified files with hk
mise run lint           # run full static analysis across the entire repository
mise run format         # format all files across the repository
```

### 2. VM Sandbox Management (in `mise.toml`)

```bash
mise run vm:start       # start the arch-basic testing VM (--headless optional)
mise run vm:stop        # ACPI graceful shutdown of VM
mise run vm:ssh         # SSH into the VM (port 22220)
mise run vm:status      # show VM running status and snapshots
mise run vm:reset       # revert VM to clean-systemd-boot snapshot
```

### 3. Machine System Bootstrap Layer (Pure Declarative)

```bash
mise bootstrap          # converge packages, files, services, dotfiles, user shell
mise bootstrap plan     # preview declarative convergence changes
```

For privileged (`/etc`, root-owned) changes, use `sudo` when a terminal is
available for the password, otherwise `pkexec` (agent/background).

## Related Standalone Projects

For detailed architecture boundaries, see [`references/related-projects.md`](references/related-projects.md):

- **`pi-quotas`** (`/home/xifan/Code/pi-quotas`): Standalone Pi CLI/plugin for AI token quota tracking. Consumed by `xifan.agents` bar plugin (`collect_pi_usage.py`).
- **`vcam`** (`/home/xifan/Code/vcam`): Android Camera2 Hook app for low-latency live streaming over LAN SRT. Driven by `livestream` / `livestream-service` on Linux.
