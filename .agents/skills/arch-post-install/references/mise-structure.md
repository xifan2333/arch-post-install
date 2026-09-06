# Mise Structure (Three-Layer Architecture)

This repo uses **mise** (>= 2026.8.14) as its declarative hub. Configuration
and tasks are structured into three distinct lifecycles so "repo dev tooling",
"machine system bootstrap", and "asset maintenance" stay completely clean.

## Layout

```
arch-post-install/
├── mise.toml                          # 1. REPO DEV & QUALITY LAYER
│   ├── [tools]                        #    Linters & formatters for this repo
│   ├── [tasks.hooks]                  #    hk installation (git hooks)
│   ├── [tasks.lint]                   #    Full repo static analysis
│   └── [tasks.format]                 #    Full repo auto-formatting
│
└── mise/
    ├── conf.d/                        # 2. SYSTEM STATE CONFIG (FRAGMENTS)
    │   ├── 10-bootstrap.toml          #    Pacman packages + privileged files
    │   └── 20-dotfiles.toml           #    Dotfiles symlink-each mappings
    ├── hooks/
    │   └── rime-wanxiang-deploy.hook  #    Pacman deployment hook (for /etc)
    └── tasks/                         # 3. SYSTEM FILE TASKS
        ├── aur                        #    [Bootstrap] AUR packages via yay
        ├── bootstrap                  #    [Bootstrap] Seed configs + nvim theme
        ├── hardware                   #    [Bootstrap] Apply fan control & GPU permissions
        ├── wps                        #    [Bootstrap] Force WPS component mode
        └── fonts                      #    [Maintenance] Pixel fonts from GitHub
```

## Layer 1: Repo Dev & Quality (`mise.toml`)

Holds the tools and tasks needed to develop and maintain this repository:

```toml
min_version = "2026.8.2"

[tools]
hk = "latest"
lua = "latest"
oxlint = "latest"
prettier = "latest"
ruff = "latest"
shellcheck = "latest"
shfmt = "latest"
stylua = "latest"
taplo = "latest"

[tasks.hooks]
description = "Install or refresh hk Git hooks"
run = "hk install"

[tasks.lint]
description = "Run full static analysis and syntax checks across the repository"
run = """
ruff check .
taplo lint --no-schema
prettier --check .
shfmt -f dotfiles/.local/bin mise/tasks | grep -vE 'i18n-(en|zh)' | xargs shellcheck --rcfile=.shellcheckrc
"""

[tasks.format]
description = "Format all Python, Shell, Lua, TOML, and JSON/YAML files across the repository"
run = """
ruff format .
shfmt -f dotfiles/.local/bin mise/tasks | xargs shfmt -w -i 4
stylua dotfiles/.config/hypr/
taplo format
prettier --write .
"""
```

- Pre-commit uses hk for fast incremental staged-file checks (~0.05s).
- `mise run lint` and `mise run format` allow manual whole-repo sweeps anytime.

## Layer 2: System Bootstrap Config (`mise/conf.d/*.toml`)

Mise auto-loads `mise/conf.d/*.toml` fragments **alphabetically**. The numeric
prefix establishes dependency order:

- `10-bootstrap.toml` — packages and privileged files (applied first)
- `20-dotfiles.toml` — dotfile symlink-each mappings (applied after packages)

`[settings] dotfiles.default_mode = "symlink"` lives in the dotfiles fragment.

## Layer 3: System & Maintenance Tasks (`mise/tasks/*`)

These are **mise file tasks**: executable scripts discovered by mise. Each
carries metadata via `#MISE` directives:

```bash
#!/usr/bin/env bash
#MISE description="Install required AUR applications"
set -euo pipefail
```

- `bootstrap` depends on `aur`, `wps`, and `hardware`, composing the system setup sequence.
- `fonts` is a standalone asset maintenance task, kept independent of bootstrap.
- All file tasks are linted with ShellCheck and formatted with Shfmt in hk's pre-commit.

## AUR packages belong in the `aur` task

Mise's built-in `pacman:` manager covers official repositories. AUR packages
require an AUR helper and building from source, so they belong in
`mise/tasks/aur`, driven by `yay` and gated with `pacman -Q` (AUR packages also
register in pacman's local database). The bootstrap flow:

1. `[bootstrap.packages] "pacman:yay" = "latest"` installs yay.
2. `bootstrap` task runs, depends on `aur`.
3. `aur` task runs `yay -S --needed` for the AUR-only packages.

## Verification commands (read-only)

```bash
mise config ls              # loaded config files in precedence order
mise tasks ls               # discovered tasks across all layers
mise tasks validate         # validate all 7 task definitions
mise bootstrap packages status
mise bootstrap files status
mise bootstrap dotfiles status
```
