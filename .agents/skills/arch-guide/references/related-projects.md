# Related Standalone Projects Index

This repository (`arch-post-install`) is the central declarative kit for the personal Arch Linux + River desktop environment. Several specialized subsystems live in standalone repositories but integrate directly with components configured here.

Use this index to understand architecture boundaries and locate the source of truth for external dependencies.

---

## Standalone Projects

### 1. `pi-quotas`

- **Location**: `/home/xifan/Code/pi-quotas` · [GitHub](https://github.com/xifan2333/pi-quotas)
- **Role**: Independent Pi extension and CLI tool for AI coding agent token quota calculation, reset window tracking, and multi-provider token usage metrics (Google AI Pro, OpenAI Codex, Claude, DeepSeek, Kimi, OpenCode, OpenRouter, xAI, Fireworks).
- **Integration Boundary**:
  - `arch-post-install` consumes the `pi-quotas` CLI binary through standalone state collectors.
  - Periodic collector tasks invoke `pi-quotas --json` on a timer and atomically write provider records to `$XDG_RUNTIME_DIR/state/agents/{provider}.json`.
  - The presentation layer is purely a view watching those state files.

### 2. `vcam` (Virtual Camera Companion)

- **Location**: `/home/xifan/Code/vcam` · [GitHub](https://github.com/xifan2333/vcam)
- **Role**: Android Camera2 Hook / Virtual Camera application for desktop-to-mobile live streaming (Douyin, WeChat Video Channels, Kuaishou).
- **Integration Boundary**:
  - `vcam` on Android listens on port 9999 for SRT streams and decodes H.264 frames directly into the camera preview Surface via hardware `MediaCodec` (zero rendering overhead, transparent physical camera bypass when stopped).
  - `arch-post-install` manages the Linux push pipeline via `custom-record start stream` (`dotfiles/.local/bin/custom-record`), which captures the screen, performs hardware encoding, and pushes over RTMP or LAN SRT (`srt://<phone-ip>:9999?mode=caller&latency=200`).
  - Stream targets and bitrates are managed interactively via `custom-record config`.

### 3. `dmnotifier` (Danmaku Desktop Notifier)

- **Location**: `/home/xifan/Code/dmnotifier`
- **Role**: Real-time live stream chat / danmaku listener and desktop notification bridge.
- **Integration Boundary**:
  - Spawned and stopped alongside the streaming session by `dotfiles/.local/bin/custom-danmaku` and `dotfiles/.local/bin/custom-record`.

### 4. `fcitx5-vinput` (Voice Input IME Integration)

- **Location**: `/home/xifan/Code/fcitx5-vinput`
- **Role**: Push-to-talk voice transcription and local LLM polishing engine wired into Fcitx5 IME.
- **Integration Boundary**:
  - Configured and linked via dotfiles (`dotfiles/.config/vinput/`).
