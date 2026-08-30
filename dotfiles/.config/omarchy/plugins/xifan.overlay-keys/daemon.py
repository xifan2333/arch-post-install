#!/usr/bin/env python3
# Screenrecord key HUD backend. Listens to keyboard input via evdev and streams
# key combinations to stdout in real-time (< 0.1ms). The xifan.overlay-keys
# Quickshell overlay reads this stream directly via Quickshell.Io.Process and
# SplitParser, avoiding all per-keystroke IPC subprocess overhead. Runs from
# inside the plugin dir via its resident python daemon.py.

import argparse
import contextlib
import fcntl
import os
import signal
import sys
import threading

try:
    from evdev import InputDevice, categorize, ecodes, list_devices
except ImportError as exc:  # pragma: no cover
    print(f"screenrecord-keys-daemon: missing python-evdev: {exc}", file=sys.stderr)
    sys.exit(1)

KEY_NAMES = {
    "KEY_LEFTCTRL": "Ctrl",
    "KEY_RIGHTCTRL": "Ctrl",
    "KEY_LEFTALT": "Alt",
    "KEY_RIGHTALT": "Alt",
    "KEY_LEFTSHIFT": "Shift",
    "KEY_RIGHTSHIFT": "Shift",
    "KEY_LEFTMETA": "Super",
    "KEY_RIGHTMETA": "Super",
    "KEY_SPACE": "Space",
    "KEY_ENTER": "Enter",
    "KEY_BACKSPACE": "Backspace",
    "KEY_ESC": "Esc",
    "KEY_TAB": "Tab",
    "KEY_UP": "Up",
    "KEY_DOWN": "Down",
    "KEY_LEFT": "Left",
    "KEY_RIGHT": "Right",
    "KEY_MINUS": "-",
    "KEY_EQUAL": "=",
    "KEY_SLASH": "/",
    "KEY_BACKSLASH": "\\",
    "KEY_DOT": ".",
    "KEY_COMMA": ",",
    "KEY_SEMICOLON": ";",
    "KEY_APOSTROPHE": "'",
    "KEY_GRAVE": "`",
    "KEY_LEFTBRACE": "[",
    "KEY_RIGHTBRACE": "]",
}
MOD_KEYS = {
    "KEY_LEFTCTRL",
    "KEY_RIGHTCTRL",
    "KEY_LEFTALT",
    "KEY_RIGHTALT",
    "KEY_LEFTSHIFT",
    "KEY_RIGHTSHIFT",
    "KEY_LEFTMETA",
    "KEY_RIGHTMETA",
}
MOD_ORDER = ["Ctrl", "Alt", "Shift", "Super"]


def pretty(code):
    if code in KEY_NAMES:
        return KEY_NAMES[code]
    if code.startswith("KEY_"):
        name = code[4:]
        if len(name) == 1:
            return name.upper()
        if name.startswith("F") and name[1:].isdigit():
            return name
        return name.title().replace("_", " ")
    return code


def keyboard_devices():
    devices = []
    for path in list_devices():
        dev = None
        try:
            dev = InputDevice(path)
            caps = dev.capabilities().get(ecodes.EV_KEY, [])
            if ecodes.KEY_A in caps and ecodes.KEY_Z in caps:
                devices.append(dev)
                dev = None
        except OSError:
            pass
        finally:
            if dev is not None:
                with contextlib.suppress(OSError):
                    dev.close()
    return devices


def emit_key(text, stdout_lock):
    """Write a single key line to stdout with microsecond latency."""
    if not text:
        return
    with stdout_lock:
        try:
            sys.stdout.write(text + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, OSError):
            sys.exit(0)


class KeyAggregator:
    def __init__(self):
        self.lock = threading.Lock()
        self.stdout_lock = threading.Lock()
        self.pressed_mods = set()

    def handle_event(self, code, state):
        name = pretty(code)
        with self.lock:
            if code in MOD_KEYS:
                if state == 1:
                    self.pressed_mods.add(name)
                elif state == 0:
                    self.pressed_mods.discard(name)
                return
            if state == 1:
                mods = [m for m in MOD_ORDER if m in self.pressed_mods]
                text = " + ".join([*mods, name]) if mods else name
            else:
                return
        emit_key(text, self.stdout_lock)


def read_device(dev, agg, stop_event):
    try:
        for event in dev.read_loop():
            if stop_event.is_set():
                break
            if event.type != ecodes.EV_KEY:
                continue
            key = categorize(event)
            code = key.keycode
            if isinstance(code, list):
                code = code[0]
            agg.handle_event(code, key.keystate)
    except OSError:
        emit_key("Input error", agg.stdout_lock)


def acquire_singleton():
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    lock_path = os.path.join(runtime_dir, "screenrecord-keys-daemon.lock")
    lock_fd = open(lock_path, "w", encoding="utf-8")  # noqa: SIM115
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        lock_fd.close()
        return None
    lock_fd.write(str(os.getpid()))
    lock_fd.flush()
    return lock_fd


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=2.0)
    parser.parse_args()

    lock_fd = acquire_singleton()
    if lock_fd is None:
        return 0

    stop_event = threading.Event()
    agg = KeyAggregator()
    agg.lock_fd = lock_fd

    devices = keyboard_devices()
    if not devices:
        emit_key("No keyboard permission", agg.stdout_lock)
    for dev in devices:
        threading.Thread(
            target=read_device, args=(dev, agg, stop_event), daemon=True
        ).start()

    def on_signal(_sig, _frame):
        stop_event.set()
        sys.exit(0)

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    while not stop_event.wait(1.0):
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
