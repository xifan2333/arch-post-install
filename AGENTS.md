# Agent Instructions & Project Index

This repository is the single source of truth for a personal Arch Linux desktop environment adhering strictly to Suckless and Unix philosophies.

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

## 2. Progressive Disclosure: Reference Index

Detailed architectural principles, development workflows, and specifications are maintained in dedicated reference documents. **Always read the matching reference file before performing relevant tasks**:

| Topic & Task Trigger | Reference Document | Purpose & Scope |
| --- | --- | --- |
| **Architecture & CLI Standards**<br>*(Writing scripts, UI strategy, i18n, design principles)* | [`.agents/skills/arch-dev/references/principles.md`](.agents/skills/arch-dev/references/principles.md) | Supreme architectural principles, Unix/Suckless standards, Language priority (`bash > lua > python`), Desktop Bin (`x-<domain>`) & zero-hardcoded i18n, UI selection hierarchy (`fuzzel > zenity > GTK`), and menu layout/alignment specs. |
| **Development Lifecycle (SOP)**<br>*(Opening PRs, branch lifecycle, task planning, merging)* | [`.agents/skills/arch-dev/references/issue-pr-workflow.md`](.agents/skills/arch-dev/references/issue-pr-workflow.md) | Mandatory closed-loop development SOP: Dual-Planning model (Phase A task plan vs Phase B quality check), strict chronological flow (Issue -> Draft PR -> Single-task loop -> Quality gate -> Atomic commit -> Unified merge). |
| **Quality Gates & Linters**<br>*(Pre-commit, hk hooks, formatters, tasks, commit-msg)* | [`.agents/skills/arch-dev/references/workflows.md`](.agents/skills/arch-dev/references/workflows.md) | Git hooks (`hk.pkl`), scoped checks (`mise run check:plan`, `mise run check:changed`), auto-fixing (`mise run fix`), linters/formatters catalogue, and Conventional Commits enforcement. |
| **Mise Declarative Spec**<br>*(Adding packages, services, bootstrap hooks, dotfile maps)* | [`.agents/skills/arch-dev/references/mise-structure.md`](.agents/skills/arch-dev/references/mise-structure.md) | The two-layer mise configuration model, declarative package definitions (`pacman:` / `aur:`), declarative services, and lifecycle hooks (`pre-packages.sh`, `post-dotfiles.sh`). |
| **Desktop Environment & Operations**<br>*(River WM, keybindings, hardware, audio, IME)* | [`.agents/skills/arch-guide/SKILL.md`](.agents/skills/arch-guide/SKILL.md) | Machine setup guide, River WM operations, layer-shell integration, Fcitx5 + Rime IME, audio routing, and hardware controls. |

---

## 3. Core Working Rules for Agents

1. **Closed-Loop Chronological Workflow**: Never write code directly on `main`. Every change must trace: `gh issue create/view` → `git checkout -b <branch>` → empty commit → `gh pr create --draft` → single-task atomic commits → `gh pr checks` → `gh pr ready` → `gh pr merge --squash --delete-branch`.
2. **Quality Gate Pre-check**: Run `mise run check:plan` to preview linters and `mise run check:changed` before committing. Use `mise run fix` for auto-formatting.
3. **Commit Messages**: Strictly follow Conventional Commits (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `style:`) with header $\le 100$ characters.
4. **Local Research First**: Speculative web searches are strictly prohibited. Always check `man <tool>` → `<tool> --help` → clone and inspect source in `~/Code/<repo>`.
