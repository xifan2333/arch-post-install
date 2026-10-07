# Desktop custom commands

All 20 repository-owned desktop commands use the `custom-` namespace:
`custom-audio`, `custom-blue`, `custom-camera`, `custom-captions`,
`custom-capture`, `custom-clipboard`, `custom-danmaku`, `custom-font`,
`custom-hardware`, `custom-i18n`, `custom-keystrokes`, `custom-live`,
`custom-ocr`, `custom-power`, `custom-record`, `custom-stream-title`,
`custom-theme`, `custom-wallhaven`, `custom-wallpaper`, and `custom-wifi`.
Use `--help` for their command syntax. Legacy executable and desktop-entry
names have been removed. Captions uses Python; the other 19 commands
use Bash.

Commands use their declared tools. They do not try alternative executables,
state directories, translation dictionaries, privilege helpers, or fabricated
values when an operation fails. Standard XDG defaults and font glyph matching
remain supported.

| Exit | Meaning |
| --- | --- |
| 0 | Success, user cancellation, or a genuinely empty list |
| 1 | Operational failure |
| 2 | Invalid arguments |
| 127 | Missing dependency |
| 130 | Interrupted by SIGINT |

Diagnostics go to stderr; stdout contains results. Fuzzel cancellation does
not execute the first row or create persistent directories. `--help` needs the
translation client and jq, but no desktop backend. `custom-i18n --help` needs
neither a dictionary nor jq.

## Connectivity, themes, and media

- `custom-blue` and `custom-wifi` default to their menus. Explicit `list` and
  `status` are read-only; device names remain escaped TSV data, and menu indices
  select backend IDs without parsing localized labels. Bluetooth discovery and
  pairing occur only after a selection; cancelling does not power the adapter.
- `custom-theme list` prints unadorned theme names; `current` prints the selected
  name or nothing when uninitialized. `set <name>` (also `<name>`) and `refresh`
  validate all palette tokens before replacing rendered files. Selection lives
  in `theme/current.name`, with palette outputs under the same XDG state directory.
  If the stored theme is removed, explicitly choose a replacement with `set <name>`
  before rerunning bootstrap; a failed refresh does not change the selection.
  Theme refresh preserves existing GTK font settings and uses native reloads or
  signals to service main processes. WM colors refresh only when the native xrwm
  status query confirms that its IPC endpoint is available. No application is
  restarted for a theme change.
- `custom-live` defaults to `status` and reports the actual service state, including
  `failed`. `start` requires a configured target; `config` explicitly opens the
  editor. Existing `livestream/history.tsv` profiles remain in XDG state, with
  empty fields preserved and writes replaced atomically at mode 0600. Querying or
  cancelling an empty editor does not create this state. Hardware changes around
  start/stop are serialized with one session-runtime lock.
- `custom-danmaku` defaults to `status`. `start` reuses the labelled Herdr workspace
  or creates its two panes; failed setup closes only that newly created workspace.
  `stop` closes the workspace, preserving unrelated workspaces and the Herdr client.
- `custom-camera` defaults to `status`. `list` emits JSON camera records;
  `start [device]` selects the specified device or the highest-ranked supported
  capture mode. Only `select` opens a picker. A repeated `start` preserves the
  running window; cancelling `select` does too.
- `custom-captions` defaults to `status`; `start` checks the configured command ASR
  provider and required audio/HUD tools before launching the service. Its internal
  `run` command requires ownership by `custom-captions.service`. Audio, provider,
  D-Bus, and HUD failures reach the service exit status. Existing `ARCH_CAPTIONS_*`
  tuning variables remain supported; invalid values are rejected on startup.

The media service names already used `custom-` and remain unchanged. The CLI rename
does not restart a running stream, recording, camera, or caption service.

## State and configuration

- Title history: `${XDG_STATE_HOME:-$HOME/.local/state}/custom-stream-title/history.txt`.
  `get` is empty when history is absent; `start` then fails. Only `edit` opens
  the title editor. `clear` hides the overlay and keeps its history.
- Font authority: `${XDG_STATE_HOME:-$HOME/.local/state}/font/fonts.conf`.
  `custom-font init "JetBrainsMono Nerd Font" "Sarasa Mono SC"` initializes
  missing state, preserves an existing selected pair, and regenerates
  `fuzzel.ini`, `ftty.toml`, `mako.conf`, `fcitx5.conf`, `waybar.css`, `wayhud.css`,
  `qt5ct.conf`, `qt6ct.conf`, and `qt.qss`. Malformed authority is
  an error. These consumers use mono first and CJK for missing glyphs. Fontconfig
  generic families (`monospace`, `sans-serif`, `serif`, `system-ui`, and `ui-*`)
  share the same selection, including the lock screen, HUDs, IME, Satty, and
  qutebrowser UI. Both `init` and `set` synchronize GTK desktop defaults via
  GSettings (requires a user D-Bus session) and generate Qt's native configuration.
  Waybar watches the generated CSS;
  `set` refreshes ftty, Mako, and Fcitx5 in process when running.
  Fuzzel reads the new pair when a menu opens.
  Wayhud 0.1.3+ watches separate theme and font CSS layers for keys, titles, and
  captions, preserving its process, layer surface, current text, and display timer.
  Instances started with older wayhud versions need a one-time reopen after upgrading.
  App-specific or
  website-specific fonts take precedence over generic defaults. Omitting CJK
  in `set` keeps the stored CJK selection.
- I18n dictionaries: `${XDG_CONFIG_HOME:-$HOME/.config}/i18n/{en-us,zh-cn}.json`.
  Chinese locales use zh-cn, English/C/POSIX use en-us. Other locales and missing
  dictionaries or keys are errors.
- Wallpapers, screenshots, and recordings are permanent user media, stored under
  XDG Pictures/Videos directories. `custom-wallpaper current` reads the managed
  wallpaper service's MainPID arguments, preserving spaces; no running image
  yields empty output, and conflicting images yield an error. `custom-wallpaper random`, the menu's
  random action, and session startup fetch and apply a random pixel-art image
  from Wallhaven (exact tag `id:2321`, SFW, at least 1920×1080). Network, download,
  or empty-result failures report an error and leave the current wallpaper in
  place; local images are not used as a fallback.

Fontconfig, Fuzzel, ftty, Mako, and Waybar configuration sources are `.tera` files in the
repository. Mise renders regular configuration files with absolute state paths.
After changing `XDG_STATE_HOME`, reapply dotfiles. Edit the `.tera` source rather
than the rendered target. The whole-tree mapping excludes template sources.
Mako includes independent font and theme fragments; switching themes preserves
the font selection.

Qt uses `QT_QPA_PLATFORMTHEME=qt5ct` (required packages: `qt5ct` and `qt6ct`).
The Qt 6 plugin also registers this key, so both versions follow the same setting,
including Qt 5 applications such as WPS. Both plugins have native
configuration-directory watchers that reload settings after a three-second debounce;
there is no font daemon or process restart. `custom-font` combines the repository's
`qt6ct/qt6ct.conf.template` with the selected mono font and generates a QSS font
family list for Qt Widgets' CJK fallback. QFont's INI serialization only preserves
one family, which is why the fallback list is a separate QSS fragment. The config
symlink is replaced atomically on each synchronization so the directory watcher
sees the event even though the generated files live under font state.

Qt's Fusion style uses the semantic desktop palette generated from
`themed/qt-colors.conf.tpl`. `custom-theme` replaces the `qt5ct/colors.conf` and `qt6ct/colors.conf` symlinks
after rendering the palette, triggering the same watcher without changing fonts.
Icons remain Adwaita and native dialogs use GTK. Changing the platform plugin
requires existing Qt processes to be opened once with the new environment;
subsequent mono-font and palette changes update them in process. Apps with their
own explicit fonts, stylesheets, or bundled Qt plugins may override these defaults.

Known Qt 6.11 limitation: changing only the CJK fallback can update the reported
font list while retaining the old glyph engine in an existing process. This is
tracked in [#362](https://github.com/xifan2333/arch-post-install/issues/362), separately
from configuration delivery. Do not work around it by restarting applications
from `custom-font`, inventing font names, or changing font sizes.

Fcitx5's non-font UI settings come from `fcitx5/classicui.conf.template` in the
repository. `custom-font init` and `set` append explicit primary/fallback font
families for candidates, menus, and tray text to the generated `font/fcitx5.conf`
and link `fcitx5/conf/classicui.conf` to it. The existing targeted D-Bus reload
then updates classicui without relying on cached generic-family matches.
Edit the repository template for non-font UI settings; GUI changes to the
generated file are replaced by the next font synchronization.

Apply the current dotfiles and initialize missing font state:

```bash
mise bootstrap dotfiles apply --yes
custom-font init "JetBrainsMono Nerd Font" "Sarasa Mono SC"
```

Mise removes only obsolete links recorded as managed by its whole-tree mapping.

## Session lifecycle

Desktop entrypoints call `uwsm app -t service -- command ...` directly.
Fuzzel resolves desktop entries before invoking its UWSM launch prefix.
Background components add `-s b`, a fixed `-u <unit>`, and
`-p PartOf=graphical-session.target`. Existing tools query their own unit with
`systemctl --user show` and stop it with `systemctl --user stop`.

`uwsm app -t scope -- command ...` waits for the application and preserves its
standard streams. Capture previews/editors and the lock screen use scopes so
image cleanup and swayidle's blocking lock invocation retain their ordering.
Use UWSM and systemctl at these call sites; no shared session wrapper is needed.
See [the lifecycle rules](../../arch-dev/references/principles.md#14-desktop-application-lifecycle-uwsm--systemd).

Waybar, Mako, and Fcitx5 reuse their native services. Font/theme changes use
Waybar's `reload_style_on_change` to watch imported CSS, preserving bars and
module processes. Mako's native `ExecReload` runs `makoctl reload` over D-Bus.
The generated `app-org.fcitx.Fcitx5@autostart.service` gets an `ExecReload`
drop-in calling D-Bus `ReloadAddonConfig("classicui")` with service activation
disabled. Fcitx5's global `ReloadConfig` does not reload classicui appearance;
its D-Bus `Restart` restarts the process and must not be used for appearance
changes. Font/theme refresh invokes the Mako/Fcitx5 reloads and signals managed
ftty main processes, preserving terminal shells and jobs. Existing terminals
launched before migration retain their original ownership until closed; open a
new terminal to use managed font reload.

When adopting this configuration in a running session, run
`systemctl --user daemon-reload` to load the Fcitx5 drop-in and reload Waybar's
configuration once with `systemctl --user reload waybar.service` to enable CSS
watching. Subsequent font/theme changes only update its styles.

| Component | User service |
| --- | --- |
| Launcher | `custom-launcher.service` |
| Polkit / idle | `custom-polkit.service` / `custom-idle.service` |
| Clipboard watchers | `custom-clipboard-text.service` / `custom-clipboard-image.service` |
| Keys / title HUD | `custom-keystrokes.service` / `custom-stream-title.service` |
| Camera / captions | `custom-camera.service` / `custom-captions.service` |
| Recording / live stream | `custom-record.service` / `custom-live.service` |
| Herdr terminal | `custom-danmaku.service` |
| Wallpaper request / renderer | `custom-wallpaper-fetch.service` / `custom-wallpaper-<number>-<number>.service` |

Caption workers and Herdr pane commands inherit their parent's unit. Status,
stop, and reload use service state, with no PID files or process-name discovery.
Inspect logs with `journalctl --user -u <unit>`. Streaming uses SIGINT on stop,
retains failed units, and restores hardware settings on explicit stop even after
encoder failure. Wallpaper replacement serializes launches and stops only old
renderer services after the new renderer starts. Session logout uses `uwsm stop`.

## Image streams

Screenshot commands accept `-o <path>`, `-o -`, or the shorthand `-`.
An image sent to stdout does not also modify the clipboard or create a screenshot
directory. Saved screenshots print their path and copy the completed image.

`custom-wallhaven download` streams image bytes when stdout is redirected;
`-o <path>` explicitly saves a file and prints that path. `menu` and
`random <query>` always save the selected image and print its path, even when
stdout is redirected. `random` uses Wallhaven's random sorting and fails when
no images match. A failed download leaves an existing target untouched.

```bash
custom-capture full -o - | custom-ocr -
custom-wallhaven download 852109 -o "$XDG_PICTURES_DIR/wallpapers/example.jpg"
custom-wallhaven download 852109 -o - | custom-wallpaper set --image-stdin
printf '%s\n' /path/to/image.png | custom-wallpaper set -
```

`custom-wallpaper set -` consumes path/URL lines;
`set --image-stdin` consumes image bytes. Wallpaper launch uses UWSM. Image
validation and a successful new launch precede stopping the previous swaybg.

## Recording

`custom-record` defaults to `status`. The menu is explicit: `custom-record menu`.
Full and area recordings use `-cr full -ffmpeg-video-opts "qp=10"`, the
visually verified settings for this desktop.
Both modes mix system playback and the default microphone into one audio track
with `-a 'default_output|default_input'`. The current default input is used,
including an audio-processing source such as RNNoise when selected. Muting the
default microphone also silences its contribution to the recording.
A single transient user unit, `custom-record.service`, owns each recording.
`Type=exec` checks executable startup; duplicate starts are refused. The service
uses SIGINT for stop so the encoder can finalize the video, and no automatic
SIGKILL is configured. Status and duration use the unit's state and main PID;
other recorder processes, including livestreams, are not discovered or signaled.

Failed units remain failed and are visible in text/Waybar output (exit 1).
Inspect `journalctl --user -u custom-record.service`. An explicit `full` or `area`
start can reset a previous failure; `toggle` does not hide it. Cancelling area
selection preserves the previous service state.

## Verification

```bash
mise run check:plan
mise run check:changed
mise run lint
```

CI runs the repository linters. Validate runtime behavior with checks appropriate
to the changed command.
