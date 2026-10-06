# Desktop custom commands

The public desktop commands are `custom-audio`, `custom-capture`,
`custom-clipboard`, `custom-font`, `custom-hardware`, `custom-i18n`,
`custom-keystrokes`, `custom-ocr`, `custom-power`, `custom-record`,
`custom-stream-title`, `custom-wallhaven`, and `custom-wallpaper`.
Use `--help` for their command syntax. Legacy command symlinks have been removed.
Independent programs such as `x-blue`, `x-wifi`, `x-theme`, and `x-live` retain
those names.

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

## State and configuration

- Title history: `${XDG_STATE_HOME:-$HOME/.local/state}/custom-stream-title/history.txt`.
  `get` is empty when history is absent; `start` then fails. Only `edit` opens
  the title editor. `clear` hides the overlay and keeps its history.
- Font authority: `${XDG_STATE_HOME:-$HOME/.local/state}/font/fonts.conf`.
  `custom-font init "JetBrainsMono Nerd Font" "Sarasa Mono SC"` initializes
  missing state, preserves an existing selected pair, and regenerates
  `fuzzel.ini`, `ftty.toml`, `mako.conf`, and `waybar.css`. Malformed authority is
  an error. These consumers use mono first and CJK for missing glyphs. Fontconfig
  generic families (`monospace`, `sans-serif`, `serif`, `system-ui`, and `ui-*`)
  share the same selection, including the lock screen, HUDs, IME, Satty, and
  qutebrowser UI. Both `init` and `set` synchronize GTK/Qt desktop defaults via
  GSettings (requires a user D-Bus session); `set` reloads Waybar, ftty, Mako,
  and Fcitx5 when running. Fuzzel reads the new pair when a menu opens.
  Reopen existing windows/HUDs without font reload support. App-specific or
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
the font selection. Qt inherits the GTK font through `QT_QPA_PLATFORMTHEME=gtk3`.

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

Waybar, Mako, and Fcitx5 reuse their native services. The generated
`app-org.fcitx.Fcitx5@autostart.service` gets an `ExecReload=fcitx5-remote -r`
drop-in. Font/theme refresh invokes those reloads and signals managed ftty main
processes, preserving terminal shells and jobs. Existing terminals launched
before migration retain their original ownership until closed; open a new
terminal to use managed font reload.

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
