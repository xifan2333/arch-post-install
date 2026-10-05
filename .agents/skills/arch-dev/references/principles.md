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

### 3.4 Pure Script Standards (Hierarchy: `bash` > `lua` > `python`)
- **First Priority: Pure Bash (`bash` + `awk` / `sed` / `grep` / `jq`)**: Mandatory for system glue, hardware controls, state collectors, and CLI dispatchers. Instant startup (< 2ms), zero disk bytecode cache.
- **Second Priority: Pure Lua (`luajit` / `lua`)**: Preferred for complex system IPC (e.g. D-Bus asynchronous communication in `x-blue` / `x-wifi`), real-time data structures, or multi-dimensional palette rendering (`x-theme`). Runs purely in memory with native execution speed, minimal RAM footprint (< 2 MB), and zero disk bytecode cache.
- **Third Priority: Pure Python 3 (`python3`)**: Strictly constrained to audio/video inferencing (`x-captions`), camera PIP overlays (`x-camera`), or long-running daemons. **Strict constraints**:
  - Standard library or declared system packages only (zero `pip` dependencies).
  - Zero bytecode cache enforced via `PYTHONDONTWRITEBYTECODE=1` in environment and script shebang (`#!/usr/bin/env -S PYTHONDONTWRITEBYTECODE=1 python3`).

### 3.5 Authoritative Research & Tooling Investigation Protocol (No Speculative Searching)
When investigating tools, CLI flags, configuration formats, or protocols:
- **Priority 1: Local `man <tool>`**: Always check local manual pages first for exact flags, environment variables, and protocol specifications.
- **Priority 2: Built-in `<tool> --help` / `-h`**: Inspect CLI flags and usage directly.
- **Priority 3: Upstream Source Inspection in `~/Code/`**: If local documentation is insufficient or a package is not yet installed, clone the repository into `~/Code/<repo>` (via `git clone --depth 1 <url>`) and directly inspect source code, CLI structs, and configuration examples.
- **Strict Prohibition**: Never perform speculative or random web searches when authoritative manpages, CLI help, or upstream source code can be directly inspected locally.

---

## 4. Desktop Bin Architecture & UI/Menu Standards

### 4.1 Universal CLI Convention (`x-<domain>`) & Metadata Header
- **Single-Character Namespace**: All scripts under `dotfiles/.local/bin/` must use the unified `x-<domain>` namespace (e.g. `x-audio`, `x-wifi`, `x-blue`, `x-wall`, `x-theme`, `x-rec`, `x-cap`).
  - Guarantees 100% collision-free isolation from system `pacman` and `AUR` binaries.
  - Offers instant tab-completion via `x-<TAB>`.
- **Standardized Metadata Header**: Every executable script must begin with structured metadata comments:
  ```bash
  # arch:summary=Manage, switch, or select desktop wallpapers
  # arch:args=[menu | list | current | ...]
  # arch:examples=x-wall current | x-wall set ~/Pictures/wallpapers/a.jpg
  ```
- **CLI Behavior**: Support `-h` / `--help`, emit structured plain text (TSV / Key-Value) in subcommands for pipeline composition, and direct errors to `stderr`.

### 4.2 Global i18n & Zero Hardcoded Strings Policy
- **Zero Hardcoded User-Facing Text**:
  - Notifications (`notify-send`), dmenu/fuzzel prompts (`--prompt`), menu option labels, and user-facing error messages must NEVER contain hardcoded English or Chinese strings in code.
- **Centralized Dictionary Registry**:
  - All user-facing strings must be declared pair-wise in `dotfiles/.config/i18n/zh-cn.json` and `dotfiles/.config/i18n/en-us.json`.
  - Keys use structured snake_case: `<domain>_notify_title`, `<domain>_menu_prompt`, `<domain>_mode_<name>`, `<domain>_failed`.
- **Graceful Fallback**:
  - Always invoke with fallback protection:
    ```bash
    x-i18n get <key> [var=val] 2>/dev/null || echo "Fallback Text"
    ```

### 4.3 UI Selection Strategy Hierarchy (`fuzzel` > `zenity` > `custom GTK`)
Desktop tools follow a strict three-tier UI strategy to prevent visual clutter and resource bloat:

```
+------------------------------------------------------------+
| Tier 1: Fuzzel --dmenu (Default: ~90% of desktop tasks)    |
| Keyboard-driven / Layer-shell / Instant / Theme-synced     |
+-----------------------------+------------------------------+
                              | Multi-field / structured forms
+-----------------------------v------------------------------+
| Tier 2: Zenity (Secondary: ~8% of desktop tasks)           |
| Multi-entry forms / Password prompts / Progress / Confirm  |
+-----------------------------+------------------------------+
                              | Complex stateful widgets
+-----------------------------v------------------------------+
| Tier 3: Custom GTK / PyGObject (Last resort: ~2% of tasks) |
| Complex stateful panels (when exceeding dmenu capabilities) |
+------------------------------------------------------------+
```

1. **Tier 1 (Default): `fuzzel --dmenu`**:
   - Primary launcher for list filtering, mode toggling, single-line input, and quick action dispatch.
   - Wayland-native layer-shell surface, cold-boots in < 5ms, supports Rofi extended icon protocol.
2. **Tier 2 (Secondary): `zenity`**:
   - Used when standard dmenu cannot express the interaction: multi-field structured forms, masked password inputs, native file pickers, or destructive operation confirmations.
   - Relies on system C library binary without custom script runtimes.
3. **Tier 3 (Last Resort): Custom GTK (`PyGObject`)**:
   - Strictly reserved for complex multi-control panels with dynamic cards, sliders, and live state that exceed Fuzzel and Zenity capabilities.
   - Must be single-file self-contained, enforce `PYTHONDONTWRITEBYTECODE=1`, and follow desktop light/dark theme tokens.

### 4.4 Menu Specifications (`dmenu` / Fuzzel Interaction)
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
