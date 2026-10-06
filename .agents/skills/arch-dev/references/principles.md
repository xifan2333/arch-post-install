# Project Principles & Architectural Manifesto

> **Core Purpose**: To build and govern a personal Arch Linux desktop environment adhering strictly to **Suckless** and **Unix** philosophies: lightweight, transparent, self-contained, and fully owned by the user.

---

## 1. Unix Philosophy in Desktop Governance

### 1.1 Single Responsibility (Do One Thing and Do It Well)
- **Compositor vs. Window Manager Separation**:
  - The compositor (e.g. River) strictly manages hardware rendering, output, and low-level Wayland protocol handling.
  - The window manager (a dedicated client) strictly manages layout policy, focus, and keybindings.
- **Collector / Display Separation**:
  - Data collectors (daemons, polling scripts for GPU, fan, livestream, token quotas) only gather data and atomically write standard JSON files to `$XDG_RUNTIME_DIR/state/*.json`. They never touch UI.
  - Presentation interfaces (status bars, OSDs, notifications) only read state files reactively. They never perform heavy blocking compute or network requests in the UI thread.

### 1.2 Composition Over Integration
- Avoid monolithic desktop frameworks or proprietary IPC systems with hidden abstractions.
- All inter-component communication relies on open, universal mechanisms:
  - Standard Wayland extension protocols (e.g., `river-window-management-v1`).
  - Kernel and userspace virtual filesystems (`/sys`, `/proc`, `/run`).
  - POSIX pipes, standard signals, and atomic file replacements.

### 1.3 Text as the Universal Interface
- All internal communication, palette definitions, and configuration fragments must use human-readable formats (TOML, INI, JSON, or plain key-value text).
- State and diagnostics must be inspectable, filterable, and replayable using standard utilities (`cat`, `grep`, `jq`).

---

## 2. Suckless Philosophy in Architecture

### 2.1 Mechanism Over Policy
- The system core provides mechanism; user code determines policy.
- No upstream framework may impose non-negotiable default behaviors or proprietary bindings.

### 2.2 Cognitive Maintainability (Clarity Over Cleverness)
- **Minimal footprint**: If a task can be accomplished with a 50-line POSIX shell script, do not introduce a heavy background daemon or complex runtime.
- **Understandability**: The entire system configuration and supporting tooling should remain small enough that the user can understand and maintain every single line.

### 2.3 Zero Bloat & Resource Frugality
- **Minimalist infrastructure**: Prefer `iwd` + `systemd-networkd` + `systemd-resolved` over heavyweight network managers with dozens of background dependencies.
- **Lightweight terminals**: Choose terminals that cold-boot in milliseconds with minimal base memory (< 10 MB per instance), avoiding bloated GPU compute pipelines for simple text rendering.
- **On-demand execution**: Avoid persistent polling daemons where systemd user timers, socket activation, or event hooks suffice.

---

## 3. Engineering & Delivery Standards

### 3.1 Absolute Self-Containment & Portability
- All desktop configurations, scripts, and assets are fully self-contained within this repository and standard XDG locations (`$XDG_CONFIG_HOME`, `$XDG_DATA_HOME`, `$XDG_STATE_HOME`).
- A freshly installed vanilla Arch Linux machine must be able to bootstrap the full environment cleanly via `mise bootstrap`.

### 3.2 Declarative & Strictly Idempotent
- Packages must be declared natively (using mise `pacman:` and `aur:` providers).
- Running the bootstrap sequence once or a hundred times must yield an identical, converged state with zero side-effects.

### 3.3 Local-First & Resilient
- The core desktop experience, window management, terminal, and Chinese IME (Fcitx5 + Rime Xiaohe Double Pinyin) must operate 100% offline without external network dependencies.

### 3.4 Pure Script Standards (Hierarchy: `bash` > `python`)
- **First Priority: Pure Bash (`bash` + `awk` / `sed` / `grep` / `jq`)**: Mandatory for system glue, hardware controls, state collectors, D-Bus communication (via native CLI tools like `bluetoothctl`, `iwctl`, `busctl`), and CLI dispatchers. Instant startup (< 2ms), zero disk bytecode cache.
- **Second Priority: Pure Python 3 (`python3`)**: Strictly constrained to audio/video inferencing (`x-captions`), camera PIP overlays (`x-camera`), or long-running daemons. **Strict constraints**:
  - Standard library or declared system packages only (zero `pip` dependencies).
  - Zero bytecode cache enforced via `sys.dont_write_bytecode = True` and runtime environment.

### 3.5 Authoritative Research & Tooling Investigation Protocol (No Speculative Searching)
When investigating tools, CLI flags, configuration formats, or protocols:
- **Priority 1: Local `man <tool>`**: Always check local manual pages first for exact flags, environment variables, and protocol specifications.
- **Priority 2: Built-in `<tool> --help` / `-h`**: Inspect CLI flags and usage directly.
- **Priority 3: Upstream Source Inspection in `~/Code/`**: If local documentation is insufficient or a package is not yet installed, clone the repository into `~/Code/<repo>` (via `git clone --depth 1 <url>`) and directly inspect source code, CLI structs, and configuration examples.
- **Strict Prohibition**: Never perform speculative or random web searches when authoritative manpages, CLI help, or upstream source code can be directly inspected locally.

---

## 4. Custom Script Architecture & Standards

All desktop utilities, custom commands, and scripts under `dotfiles/.local/bin/` follow the unified `custom-<domain>` namespace and strictly adhere to the following design principles, execution invariants, and UI standards.

### 4.1 Design Criteria (Evaluating Script Existence & Boundaries)

1. **Clear Value**: Every script must solve an explicit, tangible problem, reducing manual repetition or invocation complexity. Any new abstraction or wrapper must yield measurable maintainability or performance dividends; zero-gain wrappers are strictly prohibited.
2. **Single Responsibility**: Each script is organized around a single, coherent goal. Logic that changes together lives together; capabilities with independent utility maintain strict boundaries without cross-domain pollution.
3. **Composition Over Monolithic**: Prefer composing standard Unix tools and existing desktop utilities. Core capabilities expose orthogonal, atomic subcommands, leaving the workflow orchestration to pipelines or callers rather than hardcoding business flows into the underlying mechanism.
4. **Separation of Mechanism and Policy**: Low-level scripts provide clean, reusable operational mechanisms (headless, policy-free). User preferences, visual menus, and keybindings represent presentation policy, expressed through arguments, configuration files, or higher-level workflows.
5. **Transparent & Predictable**: Inputs (`stdin`/arguments), outputs (`stdout`), diagnostics (`stderr`), dependencies, side effects, and failure behaviors must be unambiguous. Callers can safely and correctly use the tool from its documentation and `--help` without reading source code.
6. **Holistic Simplicity**: Restrict the overall complexity of code, external dependencies, abstraction depth, and call chains. Splitting, merging, or extracting shared helpers must always be justified by lowering long-term system maintenance costs.

---

### 4.2 Hard Invariants & Execution Rules (Implementation Redlines)

1. **Unified Command Namespace (`custom-<domain>`)**:
   - Public commands strictly adopt the **`custom-<domain>`** naming convention (e.g. `custom-wifi`, `custom-audio`, `custom-cap`, `custom-theme`).
   - Guarantees 100% collision-free isolation from system `pacman` and `AUR` binaries while enabling fast, predictable tab-completion.
2. **Standard ShellDoc Comment Header (No Private Prefixes)**:
   - Every executable script must begin with a standardized ShellDoc / JSDoc comment block. Proprietary prefixes (such as `arch:`) are strictly prohibited:
     ```bash
     #!/usr/bin/env bash
     #
     # @name         custom-wall
     # @summary      Manage, switch, or select desktop wallpapers
     # @version      1.0.0
     # @deps         fuzzel, grim, magick
     #
     # @description  Universal desktop wallpaper manager for River WM.
     #               Supports random selection, local browsing, and remote search.
     #
     # @usage        custom-wall [options] <command> [arguments...]
     #
     # @options
     #   -h, --help  Show this help message and exit
     #   -q, --quiet Suppress notification dialogs
     #   --json      Output machine-readable JSON to stdout
     #
     # @commands
     #   menu        Open interactive selection launcher via Fuzzel
     #   current     Print active wallpaper path to stdout
     #   list        List all available wallpaper paths
     #   set <file>  Set wallpaper from specified path, URL, or stdin (-)
     #
     # @stdin        Accepts a file path, image URL, or stream of wallpaper candidate paths
     # @stdout       Pure text / JSON data of current wallpaper path or candidates
     # @stderr       Diagnostic errors and non-zero exit reason
     #
     # @examples
     #   custom-wall current
     #   custom-wall set ~/Pictures/wallpaper.jpg
     #   find ~/Pictures -name '*.png' | custom-wall set -
     ```
3. **Zero Hardcoding Baseline**:
   - **Display Strings**: Prompts, menu labels, notification text, help messages, and diagnostic strings **must route 100% through `custom-i18n get <key>`**, maintained in pair-wise parity across `dotfiles/.config/i18n/zh-cn.json` and `en-us.json`. Hardcoded Chinese or English text in script source is strictly prohibited.
   - **Absolute Paths**: Never hardcode `/home/<user>` or `~/.local`. Always dynamically resolve paths via standard environment variables (`$HOME`, `$XDG_*`).
   - **Hardware Identifiers**: Never hardcode network interfaces (e.g. `wlan0`), audio card IDs, or display output names; auto-detect or allow CLI/config overrides.
   - **Visual Styling & Colors**: Never hardcode hex color values (`#ffffff`). Always read tokens generated by the global semantic theme pipeline (`custom-theme`).
   - **Magic Numbers & Timeouts**: Timeouts, retry counts, and port numbers must be declared as top-level variables with sensible defaults.
4. **Strict XDG Compliance & Stateless by Default (极小化与默认无状态)**:
   - **Stateless by Default**: Custom scripts are stateless by default. Do NOT create dedicated subdirectories across `~/.config`, `~/.local/state`, `~/.cache`, or `~/.local/share` unless the script intrinsically requires permanent user configuration or persistent assets.
   - **Minimal Footprint**: At most ONE core output directory may be declared if genuinely required (e.g., `save_dir` in `$XDG_PICTURES_DIR` for screenshots, `$XDG_VIDEOS_DIR` for recordings).
   - **Path Resolution**: When XDG directories are genuinely needed, use safe fallback expansions:
     - Configuration: `${XDG_CONFIG_HOME:-$HOME/.config}/custom-<domain>`
     - Runtime tmpfs: `${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/custom-<domain>`
   - Never create dotfiles or dotdirs directly under `$HOME`. Ephemeral scratchpads must use standard `mktemp -d -t custom-<domain>.XXXXXX` and be cleaned up promptly.
5. **Full Standard I/O (`stdin` / `stdout` / `stderr`) Contract**:
   - **stdin**: Accept streaming input when `-` is specified as an argument or when piped in non-interactive mode (`[[ ! -t 0 ]]`).
   - **stdout**: Dedicated exclusively to valid result data or machine-readable JSON. Decorative human text is strictly forbidden; strip ANSI escape codes when stdout is redirected to a pipe (`[[ ! -t 1 ]]`).
   - **stderr**: Dedicated exclusively to progress indicators, operational diagnostics, and error reporting.
6. **Notification Standard (Title Strictly Matches Domain i18n)**:
   - **Standardized Title**: The notification summary/title **must strictly be the localized domain name itself** (obtained via `custom-i18n get "domain_${DOMAIN}"`, e.g. `"Wi-Fi"`, `"Audio"`, `"Bluetooth"`, `"Wallpaper"`). Scripts must not construct arbitrary descriptive titles.
   - **Clean Body**: Dynamic statuses, switched targets, and error details belong solely in the notification body.
   - **Tagging & In-Place Replacement**: Always pass `-a "custom-${DOMAIN}"` and `-h "string:x-canonical-private-synchronous:${DOMAIN}"` to ensure rapid status changes update in-place without notification spam.
7. **Language Hierarchy (`bash` > `python`)**:
   - **Bash** (`bash` + POSIX core utilities): The standard primary language for all system operations, hardware controls, CLI dispatch, state collection, and menu orchestration. Instant cold startup (< 2ms), zero toolchain complexity, zero disk bytecode cache.
   - **Python 3**: Strictly confined to media inference, streaming pipelines, or complex GUI panels where Bash cannot suffice. No third-party pip dependencies; zero bytecode cache enforced.
8. **Protocol Stability**:
   - Command names, subcommands, arguments, state machine tokens, and JSON keys are immutable protocol interfaces and must never be translated. Display text and data contracts remain strictly decoupled.
9. **Explicit Interaction & Headless Safety**:
   - Interactive pickers (Fuzzel) and dialogs (Zenity) are explicit interaction entrypoints. When complete parameters are supplied via CLI, the command must execute directly without popping UI.
   - Missing parameters in a headless or non-interactive environment (non-TTY `[[ ! -t 0 ]]` or missing `$WAYLAND_DISPLAY`) must immediately exit with an error on `stderr`, never hanging or spawning GUI dialogs.
10. **UI Strategy Hierarchy (`fuzzel` > `zenity` > `custom GTK`)**:
    - **Tier 1 (Default: ~90% of tasks) - Fuzzel**: Single-line text input, list filtering, mode toggling, and instant execution (cold startup < 5ms, Wayland layer-shell native).
    - **Tier 2 (Secondary: ~8% of tasks) - Zenity**: Multi-field structured forms, masked password entry, native file picking, or destructive confirmation prompts.
    - **Tier 3 (Last Resort: ~2% of tasks) - Custom GTK Panel (`PyGObject`)**: Multi-card dynamic panels with sliders and real-time state exceeding Fuzzel/Zenity capabilities.
11. **Query Has No Side Effects**:
    - Commands named `get`, `list`, `status`, or `current` must be strictly read-only. They must never trigger hardware scans, network reconnects, configuration modifications, or daemon processes.
12. **Safe Argument Handling & Injection Prevention**:
    - Arguments pass as raw values with strict double-quoting `"$arg"`.
    - Dynamic execution via `eval` is strictly prohibited. Never infer or reverse-engineer entity IDs from localized display labels.
13. **Strict Exit Code Contract (POSIX / sysexits)**:
    - `0`: Success (or clean user cancellation via Esc/Cancel with zero side effects).
    - `1`: General operational failure (network error, connection timeout).
    - `2`: Command-line usage error, missing argument, or illegal option.
    - `127`: Missing required system dependency.
    - `130`: Interrupted by `SIGINT` (Ctrl+C).
    - Never mask critical failures with `|| true`.
14. **Bash Execution Environment & Scoping**:
    - Always declare `set -euo pipefail`.
    - All internal function variables must be declared with `local`; internal variables must be lowercase.
15. **Atomic State Mutation & Idempotence**:
    - State writes (configurations, state JSON files) must write to a temporary file first and atomically overwrite via `mv -f`. In-place overwriting (`>` or `sed -i`) on live state is forbidden.
    - Mutation operations must be idempotent: executing the same set command multiple times yields the identical state without errors.
16. **Resource Lifecycle, Traps & Single-Instance Locking (生命周期与就地清理)**:
    - **Local Cleanup vs. Global Traps**:
      - Ephemeral, function-local temporary files (such as scratch images or menu icons inside a picker function) MUST be cleaned up locally before the function returns. **NEVER register a global process `EXIT` trap for function-local variables**, which causes unbound variable crashes under `set -u` after function return.
      - Global `trap cleanup EXIT INT TERM HUP` is strictly reserved for process-level, long-running lifecycles (e.g. background recording daemons, live streams, or single-instance lockfiles).
    - **Single-Instance Locking**: Exclusive background actions (recording, live streaming, webcam overlay) must enforce single-instance locking via `flock` or `$XDG_RUNTIME_DIR/custom-<domain>/run.pid`, verify liveness with `kill -0`, and provide idempotent `toggle`, `start`, `stop`, and `status` actions.
17. **Contract Verification & Static Analysis Gate**:
    - Scripts must pass linters (`shellcheck` + `shfmt` for Bash, `ruff` for Python, `stylua` for Neovim config).
    - Must explicitly test four runtime scenarios: normal operation, invalid arguments, user cancellation, and edge-case special character inputs.

---

### 4.3 Menu Specifications (`dmenu` / Fuzzel Interaction)
To maintain consistent muscle memory and visual harmony across all CLI menus:

1. **Level & Cognitive Load**:
   - **Single-Level Flat Menu**: Used when options $\le 8$ and have no sub-attributes (e.g. `x-power`, `x-cap`).
   - **Two-Level Menu**: Used when separating mode dispatch from entity browsing, or when items exceed 15 (e.g. `x-wall`: mode menu -> wallpaper picker).
   - **Navigation Semantics**: Submenus must provide a localized `_back` option. Esc key must always safely cancel with zero side-effects (`exit 0` / `return 0`).
2. **Visual Format & NerdFont Glyphs**:
   - Structure: `"<status_prefix><NerdFont_glyph>  <label>"` (strictly **two spaces** separating glyph and text).
   - Equal-width state alignment: Active/current item prefixed with `* `; inactive items prefixed with `  ` (two spaces) to ensure vertical text alignment. The domain NerdFont glyph remains constant across active and inactive states.
   - Standard glyph semantics:
     - 🖼 Image / Local: `󰋩` (`nf-md-image`)
     - 🎲 Random / Shuffle: `󰒝` (`nf-md-shuffle_variant`)
     - 🔍 Search: `󰍉` (`nf-md-magnify`)
     - 📶 Wi-Fi: `󰖩` (`nf-md-wifi`)
     - 󰂯 Bluetooth: `󰂯` (`nf-md-bluetooth`) / Headset `󰋋` / Speaker `󰓃`
     - 🎤 Microphone: `󰍬` (`nf-md-microphone`)
     - ⚙ Settings / Config: `󰒓` (`nf-md-cog`)
3. **Thumbnail & Icon Preview Protocol**:
   - Format: `"<label>\0icon\x1f<path>"` via Rofi extended protocol.
   - Storage: All generated thumbnails and temporary icons **MUST reside in user-private tmpfs** (`${XDG_RUNTIME_DIR:-/tmp/user-${UID:-1000}}/...`), never accumulating on persistent disk.
   - Fallback: Gracefully fallback to the designated NerdFont glyph when icons are unavailable.
4. **Instant Apply**:
   - Selecting an item applies immediately without redundant "Confirm" dialogs (except for destructive actions like reboot/poweroff).
   - Provide immediate closure feedback via `x-i18n` localized `notify-send`.
