---
name: arch-dev
description: >
  REQUIRED for developing, maintaining, and testing this personal Arch Linux +
  River desktop repository. Use whenever editing dev tooling (mise.toml),
  configuring git hooks/linters (hk.pkl), editing pre/post bootstrap hooks
  (mise/hooks/*), running code quality gates (mise run check:plan, check:changed,
  fix, lint), or following the strict Chronological Issue + Draft PR workflow
  (SOP). Trigger on: 开PR/提PR, Draft PR 工作流, 单任务循环提交, 代码体检与格式化自检,
  调整 linter.
---

# Arch Post-Install: Developer & Engineering Kit

This skill governs the engineering standards, quality gates, and development workflows for contributing to and maintaining this personal Arch Linux + River repository.

## Supreme Architectural Principles (最高原则)

All engineering, architecture, and code decisions MUST strictly adhere to the Suckless and Unix philosophies documented in [`references/principles.md`](references/principles.md):

1. **Unix Philosophy in Desktop Governance**:
   - **Compositor vs. Window Manager Separation**: The compositor (`river`) strictly handles hardware rendering and low-level Wayland protocols; the window manager (dedicated client) strictly handles layout policy, focus, and bindings.
   - **Collector / Display Separation**: Standalone collectors (`dotfiles/.local/bin/`) poll data and atomically replace `$XDG_RUNTIME_DIR/state/*.json`; UI displays (`waybar`) strictly read state reactively with zero blocking I/O or polling.
   - **Text as the Universal Interface**: Human-readable formats (TOML, JSON, INI) for all state, config, and IPC.
2. **Suckless Philosophy in Architecture**:
   - **Mechanism Over Policy**: System provides mechanism; user code determines policy.
   - **Cognitive Maintainability**: Keep code small and understandable. No bloated wrappers or monolithic frameworks.
   - **Zero Bloat & Resource Frugality**: Minimalist infrastructure (`iwd` + `systemd-networkd` + `systemd-resolved`), lightweight Wayland-native clients (`foot`), and zero background daemons where timers or socket activation suffice.
3. **Engineering & Delivery Standards**:
   - **Absolute Self-Containment**: Zero external framework lock-in. No non-standard proprietary directories.
   - **100% Declarative & Idempotent**: Pure `mise bootstrap` convergence; re-running is safe and deterministic.
   - **Pure Script First-Class Citizens (Language Priority: `sh` > `perl` > `py`)**:
     - Priority 1: Pure POSIX Shell (`sh` / `bash` + `awk` / `sed` / `grep` / `jq`) for all system control, collectors, and CLI glue (instant startup, zero cache files).
     - Priority 2: Pure Perl (`perl`) for complex text transformations, in-memory regex mappings, or multi-dimensional template rendering where shell/awk becomes convoluted (native, purely in-memory, zero bytecode cache).
     - Priority 3: Pure Python 3 (`python3`) for complex structured data or long-running daemons. **Strict constraints**:
       * Standard library only (zero `pip` dependencies).
       * Zero bytecode cache: Always enforce `PYTHONDONTWRITEBYTECODE=1` via environment and shebang (`#!/usr/bin/env -S PYTHONDONTWRITEBYTECODE=1 python3`).
   - **Universal CLI Convention (`x-<tool>`)**: All user-facing desktop tools follow the unified single-character namespace `x-<tool>` directly accessible via `$PATH`. Every script carries `# arch:summary=...` metadata.
   - **Authoritative Research Protocol**: Check `man <tool>` -> `<tool> --help` -> Clone to `~/Code/<repo>` to inspect source code. Speculative web search is strictly prohibited when authoritative docs/code can be inspected locally.

## Start Here

Read the matching reference before editing:

- [`references/principles.md`](references/principles.md) — supreme architectural manifesto and guidelines.
- [`references/issue-pr-workflow.md`](references/issue-pr-workflow.md) — mandatory Issue + Draft PR driven development workflow (SOP), Dual-Planning model, single-item loop, and merge.
- [`references/mise-structure.md`](references/mise-structure.md) — the two-layer mise configuration (Repo Dev in `mise.toml`, Declarative Machine Spec in `mise/conf.d/*.toml`, Lifecycle Hooks in `mise/hooks/*.sh`).
- [`references/workflows.md`](references/workflows.md) — git/hk conventions, linters, formatters, and task commands.

## Where Edits Go

| Goal | Target File / Directory |
| --- | --- |
| Add/change a repo linter or dev tool | `mise.toml` → `[tools]` |
| Add/update repo check or format tasks | `mise.toml` → `[tasks.*]` |
| Configure system services or privileged files | `mise/conf.d/10-system.toml` |
| Add a system package (pacman or aur) | `mise/conf.d/20-packages.toml` |
| Map a dotfile into `~/.config` / `~/.local` | `mise/conf.d/30-dotfiles.toml` |
| Update pre-packages setup hook | `mise/hooks/pre-packages.sh` |
| Update post-dotfiles runtime hook | `mise/hooks/post-dotfiles.sh` |
| Configure River window manager & compositor | `dotfiles/.config/river/` |
| Manage state collectors & CLI tools | `dotfiles/.local/bin/` |
| Dotfile sources | `dotfiles/` (never edit target symlinks directly) |

## Strict Chronological Development Workflow (SOP)

All coding agents must strictly operate within this closed-loop chronological lifecycle:

1. **Phase A: Pre-Code Initialization (MANDATORY BEFORE CODING)**:
   - Inspect issue: `gh issue view <id>`
   - Checkout branch: `git checkout -b <type>/issue-<id>-<name>`
   - Empty commit: `git commit --allow-empty -m "chore: initialize draft pr for #<id>"`
   - Push branch: `git push -u origin <type>/issue-<id>-<name>`
   - Open Draft PR: `gh pr create --draft` with ALL tasks unchecked (`- [ ]`)
2. **Single-Item Execution Loop**:
   - Implement ONLY the topmost unchecked `- [ ]` task.
   - Run local quality gate: `mise run check:plan`, `mise run check:changed`, `mise run fix`.
   - Make local atomic commit: `git commit -m "<type>(<scope>): ..."`
3. **Phase C: Unified Push, Checks & Merge**:
   - Push all commits: `git push origin <branch>`
   - Update PR body checking all completed items (`- [x]`)
   - Verify CI status: `gh pr checks`
   - Mark ready: `gh pr ready`
   - Squash merge and delete branch: `gh pr merge --squash --delete-branch`

## Quality Gate Commands

```bash
mise run check:plan     # preview which linters will run on modified files
mise run check:changed  # run hk checks across modified/staged/untracked files
mise run fix            # auto-format modified files with hk
mise run lint           # full-repo static analysis audit
mise run format         # full-repo formatting audit
```
