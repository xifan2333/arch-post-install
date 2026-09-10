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
│   ├── [tasks.format]                 #    Full repo auto-formatting
│   └── [tasks."vm:*"]                 #    VM test sandbox commands
│
└── mise/
    ├── hooks/
    │   ├── pre-packages.sh            #    Pre-packages setup hook (base-devel, archlinuxcn, yay)
    │   ├── post-dotfiles.sh           #    Post-dotfiles runtime config seeding & theme sync
    │   └── rime-wanxiang-deploy.hook  #    Pacman deployment hook (for /etc)
    └── conf.d/                        # 2. SYSTEM STATE CONFIG (FRAGMENTS)
        ├── 10-system.toml             #    System services, hooks & privileged files
        ├── 20-packages.toml           #    Declarative pacman: and aur: packages
        └── 30-dotfiles.toml           #    Dotfiles symlink-each mappings
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
shfmt -f dotfiles/.local/bin mise/hooks | grep -vE 'i18n-(en|zh)' | xargs shellcheck --rcfile=.shellcheckrc
"""

[tasks.format]
description = "Format all Python, Shell, Lua, TOML, and JSON/YAML files across the repository"
run = """
ruff format .
shfmt -f dotfiles/.local/bin mise/hooks | xargs shfmt -w -i 4
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

- `10-system.toml` — system services, privileged files, and lifecycle hooks
- `20-packages.toml` — declarative OS packages (`pacman:*` and `aur:*`)
- `30-dotfiles.toml` — dotfile symlink-each mappings

`[settings] dotfiles.default_mode = "symlink"` lives in the dotfiles fragment.

## Declarative Bootstrap vs Task Runner

Machine provisioning is 100% declarative via `mise bootstrap`. There is no
`mise/tasks/` directory: procedural task runners must never be mixed into the
declarative state convergence process. All machine state is expressed through
native `[bootstrap.*]` and `[dotfiles]` sections.

## Declarative AUR Package Management

Mise natively supports `aur:` package declarations inside `[bootstrap.packages]`
alongside official `pacman:` packages. The pre-packages hook (`mise/hooks/pre-packages.sh`)
ensures `base-devel`, the official `[archlinuxcn]` repository, and `yay` are
installed before package resolution begins. Mise then uses `yay` to install
all declared `aur:*` packages without requiring imperative bash scripts.

## Verification commands (read-only)

```bash
mise config ls              # loaded config files in precedence order
mise tasks ls               # discovered tasks across all layers
mise tasks validate         # validate all 7 task definitions
mise bootstrap packages status
mise bootstrap files status
mise bootstrap dotfiles status
```
