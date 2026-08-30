#!/usr/bin/env python3
# Screenrecord caption overlay backend. Captures audio, runs local VAD + the
# active VInput streaming ASR command provider, and pushes partial/final
# transcription text to the xifan.overlay-captions Quickshell overlay over the
# omarchy-shell IPC. No GTK / no layer-shell: the overlay is pure QML. Runs
# from inside the plugin dir via its resident python daemon.py.
#
# Env:   SCREENRECORD_OVERLAY_CAPTIONS_SOURCE  audio source (rnnoise_source)
#        OMARCHY_PATH                           default /usr/share/omarchy

import array
import base64
import contextlib
import fcntl
import json
import os
import queue
import signal
import subprocess
import sys
import threading
import time

AUDIO_SOURCE = os.environ.get("SCREENRECORD_OVERLAY_CAPTIONS_SOURCE", "rnnoise_source")
SAMPLE_RATE = 16000
CHANNELS = 1
BYTES_PER_SAMPLE = 2
FRAME_MS = 100
FRAME_BYTES = SAMPLE_RATE * CHANNELS * BYTES_PER_SAMPLE * FRAME_MS // 1000

VOICE_RMS_THRESHOLD = int(os.environ.get("SCREENRECORD_OVERLAY_CAPTIONS_RMS", "180"))
SILENCE_FRAMES_TO_FINISH = int(os.environ.get("SCREENRECORD_OVERLAY_CAPTIONS_SILENCE_FRAMES", "6"))
MAX_UTTERANCE_SECONDS = int(
    os.environ.get("SCREENRECORD_OVERLAY_CAPTIONS_MAX_UTTERANCE_SECONDS", "18")
)
MAX_CAPTION_CHARS = int(os.environ.get("SCREENRECORD_OVERLAY_CAPTIONS_MAX_CHARS", "0"))
PROVIDER_POLL_SECONDS = 2.0
VINPUT_STATUS_POLL_SECONDS = 0.5
VINPUT_BUS_NAME = "org.fcitx.Vinput"
VINPUT_OBJECT_PATH = "/org/fcitx/Vinput"
VINPUT_INTERFACE = "org.fcitx.Vinput.Service"

# VInput may be absent (headless); importing Gio is fine but bus calls degrade.
try:
    from gi.repository import Gio, GLib
except ImportError:  # pragma: no cover
    Gio = None
    GLib = None


# Errors that can escape the ASR provider session path.
_ASR_ERRORS = (RuntimeError, KeyError, OSError, TypeError, ValueError)


def log(message):
    print(f"screenrecord-captions-daemon: {message}", file=sys.stderr, flush=True)


def omarchy_path():
    return os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")


def push_caption(text, kind):
    """Send a caption update to the QML overlay via qs ipc call."""
    if kind != "clear" and not text:
        return
    omarchy_bin = os.path.join(omarchy_path(), "bin/omarchy-shell")
    with contextlib.suppress(OSError, subprocess.TimeoutExpired):
        subprocess.run(
            [omarchy_bin, "xifan.overlay-captions", "caption", text or "", kind],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=0.5,
        )


def sanitize_caption(text):
    return str(text or "").replace("\r", "").replace("\n", "").strip()


def truncate_caption(text, max_chars):
    if max_chars <= 0 or len(text) <= max_chars:
        return text
    if max_chars == 1:
        return "…"
    return "…" + text[-(max_chars - 1) :]


def pcm16_rms(chunk):
    if not chunk:
        return 0
    samples = array.array("h")
    samples.frombytes(chunk[: len(chunk) - (len(chunk) % 2)])
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        return 0
    total = 0
    for sample in samples:
        total += sample * sample
    return int((total / len(samples)) ** 0.5)


def vinput_config_get(pointer):
    try:
        proc = subprocess.run(
            ["vinput", "-j", "config", "get", pointer],
            check=True,
            text=True,
            capture_output=True,
            timeout=3,
        )
    except (
        OSError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        json.JSONDecodeError,
    ) as exc:
        raise RuntimeError(f"failed to read vinput config {pointer}: {exc}") from exc
    payload = json.loads(proc.stdout)
    return payload.get("value")


def vinput_recording_active():
    if Gio is None:
        return False
    try:
        connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        proxy = Gio.DBusProxy.new_sync(
            connection,
            Gio.DBusProxyFlags.DO_NOT_AUTO_START,
            None,
            VINPUT_BUS_NAME,
            VINPUT_OBJECT_PATH,
            VINPUT_INTERFACE,
            None,
        )
        if proxy.get_name_owner() is None:
            return False
        result = proxy.call_sync("GetStatus", None, Gio.DBusCallFlags.NONE, 100, None)
        return result.unpack()[0] != "idle"
    except (GLib.Error, OSError, TypeError):
        return False


def get_active_vinput_provider():
    active_id = vinput_config_get("/asr/active_provider")
    providers_value = vinput_config_get("/asr/providers")
    if isinstance(providers_value, str):
        providers = json.loads(providers_value)
    else:
        providers = providers_value or []

    for provider in providers:
        if provider.get("id") != active_id:
            continue
        if provider.get("type") != "command":
            raise RuntimeError(f"active ASR provider is not a command provider: {active_id}")
        command = provider.get("command")
        if not command:
            raise RuntimeError(f"active provider has no command: {active_id}")
        return {
            "id": provider.get("id", ""),
            "title": provider.get("title", provider.get("id", "")),
            "command": command,
            "args": provider.get("args") or [],
            "env": provider.get("env") or {},
        }
    raise RuntimeError(f"active ASR provider not found in config: {active_id}")


class ProviderSession:
    def __init__(self, events, provider, session_id):
        self.events = events
        self.provider = provider
        self.session_id = session_id
        self.proc = None
        self.provider_id = provider["id"]
        self.closed = False

    def start(self):
        provider = self.provider
        env = os.environ.copy()
        for key, value in provider["env"].items():
            if key:
                env[key] = str(value)
        cmd = [provider["command"], *provider["args"]]
        self.proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env=env,
        )
        self.provider_id = provider["id"]
        threading.Thread(target=self.read_stdout, daemon=True).start()
        threading.Thread(target=self.read_stderr, daemon=True).start()

    def send_audio(self, chunk):
        if not self.proc or self.closed or not self.proc.stdin:
            return
        event = {"type": "audio", "audio_base64": base64.b64encode(chunk).decode("ascii")}
        try:
            self.proc.stdin.write(json.dumps(event, ensure_ascii=False) + "\n")
            self.proc.stdin.flush()
        except (BrokenPipeError, OSError):
            self.closed = True

    def finish(self):
        if not self.proc or self.closed or not self.proc.stdin:
            return
        try:
            self.proc.stdin.write(json.dumps({"type": "finish"}) + "\n")
            self.proc.stdin.flush()
            self.proc.stdin.close()
        except (BrokenPipeError, OSError, ValueError):
            pass
        self.closed = True

    def terminate(self):
        self.finish()
        if self.proc and self.proc.poll() is None:
            with contextlib.suppress(OSError):
                self.proc.terminate()

    def read_stdout(self):
        if not self.proc or not self.proc.stdout:
            return
        for raw_line in self.proc.stdout:
            line = raw_line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            typ = event.get("type")
            text = str(event.get("text") or "").strip()
            if typ in ("partial", "final", "final_timestamps") and text:
                self.events.put((typ, text, self.session_id))
            elif typ == "error":
                self.events.put(("error", str(event.get("message") or event), self.session_id))

    def read_stderr(self):
        if not self.proc or not self.proc.stderr:
            return
        for raw_line in self.proc.stderr:
            line = raw_line.strip()
            if line:
                self.events.put(("debug", line, self.session_id))


class CaptionsDaemon:
    def __init__(self, max_chars):
        self.events = queue.Queue()
        self.stop_event = threading.Event()
        self.audio_proc = None
        self.session_lock = threading.Lock()
        self.current_session = None
        self.active_provider = None
        self.last_provider_poll_at = 0.0
        self.voice_input_active = False
        self.max_chars = max_chars

    def _clear(self, session_id=0):
        push_caption("", "clear")

    def provider_changed(self, provider):
        if not self.active_provider:
            return True
        return (
            provider.get("id") != self.active_provider.get("id")
            or provider.get("command") != self.active_provider.get("command")
            or provider.get("args") != self.active_provider.get("args")
            or provider.get("env") != self.active_provider.get("env")
        )

    def poll_active_provider(self, force=False):
        now = time.monotonic()
        if (
            not force
            and self.active_provider
            and now - self.last_provider_poll_at < PROVIDER_POLL_SECONDS
        ):
            return self.active_provider
        self.last_provider_poll_at = now
        provider = get_active_vinput_provider()
        if self.provider_changed(provider):
            self.active_provider = provider
            self.terminate_session()
        return self.active_provider

    def start_session(self, provider=None):
        if provider is None:
            provider = self.poll_active_provider(force=False)
        session = ProviderSession(self.events, provider, 1)
        session.start()
        with self.session_lock:
            self.current_session = session
        return session

    def ensure_session(self):
        provider = self.poll_active_provider(force=False)
        with self.session_lock:
            current = self.current_session
        if (
            current
            and current.proc
            and current.proc.poll() is None
            and provider
            and current.provider_id == provider.get("id")
        ):
            return current
        self.terminate_session()
        return self.start_session(provider=provider)

    def finish_session(self):
        with self.session_lock:
            if self.current_session:
                self.current_session.finish()
                self.current_session = None

    def terminate_session(self):
        with self.session_lock:
            if self.current_session:
                self.current_session.terminate()
                self.current_session = None

    def poll_vinput_status(self):
        # Non-blocking: last observed status, refreshed by the poller thread.
        return self.voice_input_active

    def poll_vinput_status_loop(self):
        while not self.stop_event.is_set():
            try:
                active = vinput_recording_active()
            except (GLib.Error, OSError, TypeError, ValueError) as exc:
                log(f"vinput status check failed: {exc}")
                active = self.voice_input_active
            if active != self.voice_input_active:
                self.voice_input_active = active
                log(f"voice input {'active' if active else 'idle'}")
                if active:
                    self.terminate_session()
                    self.events.put(("clear", "", 0))
            self.stop_event.wait(VINPUT_STATUS_POLL_SECONDS)

    def run_audio_loop(self):
        try:
            self.audio_proc = subprocess.Popen(
                [
                    "parec",
                    f"--device={AUDIO_SOURCE}",
                    "--format=s16le",
                    f"--rate={SAMPLE_RATE}",
                    f"--channels={CHANNELS}",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            log(f"audio capture started pid={self.audio_proc.pid} source={AUDIO_SOURCE}")
        except OSError as exc:
            self.events.put(("error", f"failed to start audio capture: {exc}"))
            return

        threading.Thread(target=self.read_audio_stderr, daemon=True).start()

        silence_frames = 0
        in_speech = False
        utterance_started_at = 0.0

        try:
            if not self.poll_vinput_status():
                self.ensure_session()
        except _ASR_ERRORS as exc:
            log(f"prewarm failed: {exc}")
            self.events.put(("error", str(exc)))

        try:
            while not self.stop_event.is_set():
                chunk = self.audio_proc.stdout.read(FRAME_BYTES)
                if not chunk:
                    break

                if self.poll_vinput_status():
                    in_speech = False
                    silence_frames = 0
                    continue

                rms = pcm16_rms(chunk)
                is_voice = rms >= VOICE_RMS_THRESHOLD

                with self.session_lock:
                    cur = self.current_session
                session_alive = cur and cur.proc and cur.proc.poll() is None
                if not session_alive:
                    try:
                        self.ensure_session()
                    except _ASR_ERRORS as exc:
                        self.events.put(("error", str(exc)))
                        time.sleep(1.0)
                        continue

                if self.current_session:
                    self.current_session.send_audio(chunk)

                if is_voice:
                    if not in_speech:
                        in_speech = True
                        utterance_started_at = time.monotonic()
                    silence_frames = 0
                elif in_speech:
                    silence_frames += 1

                too_long = (
                    in_speech and time.monotonic() - utterance_started_at > MAX_UTTERANCE_SECONDS
                )
                if in_speech and (silence_frames >= SILENCE_FRAMES_TO_FINISH or too_long):
                    self.finish_session()
                    try:
                        if not self.poll_vinput_status():
                            self.ensure_session()
                    except _ASR_ERRORS as exc:
                        self.events.put(("error", str(exc)))
                    in_speech = False
                    silence_frames = 0

        except (OSError, ValueError, AttributeError) as exc:
            self.events.put(("error", f"audio loop error: {exc}"))
        finally:
            self.finish_session()

    def read_audio_stderr(self):
        if not self.audio_proc or not self.audio_proc.stderr:
            return
        for raw_line in self.audio_proc.stderr:
            line = raw_line.decode(errors="ignore").strip()
            if line:
                self.events.put(("debug", line))

    def drain_events(self):
        try:
            while True:
                event = self.events.get_nowait()
                typ = event[0]
                if typ in ("partial", "final", "final_timestamps"):
                    text = truncate_caption(sanitize_caption(event[1]), self.max_chars)
                    push_caption(text, typ)
                elif typ == "error":
                    log(f"ASR error: {event[1]}")
                elif typ == "debug":
                    log(f"debug: {event[1]}")
                elif typ == "clear":
                    push_caption("", "clear")
        except queue.Empty:
            pass

    def run(self):
        threading.Thread(target=self.run_audio_loop, daemon=True).start()
        threading.Thread(target=self.poll_vinput_status_loop, daemon=True).start()
        while not self.stop_event.is_set():
            self.drain_events()
            time.sleep(0.05)

    def stop(self):
        self.stop_event.set()
        self.finish_session()
        if self.audio_proc and self.audio_proc.poll() is None:
            with contextlib.suppress(Exception):
                self.audio_proc.terminate()


def acquire_singleton():
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    lock_path = os.path.join(runtime_dir, "screenrecord-captions-daemon.lock")
    lock_fd = open(lock_path, "w", encoding="utf-8")  # noqa: SIM115
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log("already running")
        lock_fd.close()
        return None
    lock_fd.write(str(os.getpid()))
    lock_fd.flush()
    return lock_fd


def main():
    lock_fd = acquire_singleton()
    if lock_fd is None:
        return 0
    max_chars = int(os.environ.get("SCREENRECORD_OVERLAY_CAPTIONS_MAX_CHARS", "0"))
    daemon = CaptionsDaemon(max_chars)
    daemon.lock_fd = lock_fd
    log("started")

    def on_signal(_sig, _frame):
        daemon.stop()
        sys.exit(0)

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    try:
        daemon.run()
    except KeyboardInterrupt:
        daemon.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
