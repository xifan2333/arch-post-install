# Related Standalone Projects Index

This repository (`arch-post-install`) is the central declarative kit for the personal Arch Linux + Omarchy desktop environment. Several specialized subsystems live in standalone repositories but integrate directly with components configured here.

Use this index to understand architecture boundaries and locate the source of truth for external dependencies.

---

## Standalone Projects

### 1. `pi-quotas`

- **Location**: `/home/xifan/Code/pi-quotas` · [GitHub](https://github.com/xifan2333/pi-quotas)
- **Role**: Independent Pi extension and CLI tool for AI coding agent token quota calculation, reset window tracking, and multi-provider token usage metrics (Google AI Pro, OpenAI Codex, Claude, DeepSeek, Kimi, OpenCode, OpenRouter, xAI, Fireworks).
- **Integration Boundary**:
  - `arch-post-install` consumes the `pi-quotas` CLI binary through the `xifan.agents` Omarchy bar plugin (`dotfiles/.config/omarchy/plugins/xifan.agents/collect_pi_usage.py`).
  - `collect_pi_usage.py` invokes `pi-quotas --json` on a 15-minute timer / manual refresh and atomically writes provider records to `~/.local/state/omarchy/agents/usage/{provider}.json`.
  - The UI widget (`Panel.qml`, `Agent.qml`) is purely a view layer watching those files.

### 2. `vcam` (Virtual Camera Companion)

- **Location**: `/home/xifan/Code/vcam` · [GitHub](https://github.com/xifan2333/vcam)
- **Role**: Android Camera2 Hook / Virtual Camera application for desktop-to-mobile live streaming (Douyin, WeChat Video Channels, Kuaishou).
- **Integration Boundary**:
  - `vcam` on Android listens on port 9999 for SRT streams and decodes H.264 frames directly into the camera preview Surface via hardware `MediaCodec` (zero rendering overhead, transparent physical camera bypass when stopped).
  - `arch-post-install` manages the Linux push pipeline via `livestream` / `livestream-service` (`dotfiles/.local/bin/livestream*`), which captures the screen, performs 9:16 vertical composition, VAAPI NV12 hardware encoding, and pushes over LAN SRT (`srt://<phone-ip>:9999?mode=caller&latency=200`).
  - Stream targets and bitrates (`lan_bitrate`, `aspect_ratio: "9:16"`) are configured in `~/.config/livestream/config.json`.

### 3. `dmnotifier` (Danmaku Desktop Notifier)

- **Location**: `/home/xifan/Code/dmnotifier`
- **Role**: Real-time live stream chat / danmaku listener and desktop notification bridge.
- **Integration Boundary**:
  - Spawned and stopped alongside the streaming session by `dotfiles/.local/bin/livestream-danmaku` and `dotfiles/.local/bin/livestream`.

### 4. `fcitx5-vinput` (Voice Input IME Integration)

- **Location**: `/home/xifan/Code/fcitx5-vinput`
- **Role**: Push-to-talk voice transcription and local LLM polishing engine wired into Fcitx5 IME.
- **Integration Boundary**:
  - Configured and linked via dotfiles (`dotfiles/.config/vinput/`).
