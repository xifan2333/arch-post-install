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

### 3.4 Pure Script Standards (Hierarchy: `sh` > `perl` > `py`)
- **First Priority: Pure Shell (`sh` / `bash` + `awk` / `sed` / `grep` / `jq`)**: Mandatory for system glue, hardware controls, state collectors, and CLI dispatchers. 0ms startup, zero cache files.
- **Second Priority: Pure Perl (`perl`)**: Preferred when complex text manipulation, in-memory regex mappings, or template rendering is required. Native, purely in-memory execution, and never leaves disk bytecode cache.
- **Third Priority: Pure Python 3 (`python3`)**: Strictly constrained to standard library only (zero pip dependencies). Zero bytecode cache is enforced via `PYTHONDONTWRITEBYTECODE=1` in environment and script shebangs (`#!/usr/bin/env -S PYTHONDONTWRITEBYTECODE=1 python3`).
