"""Stream recording state on systemd events; tick elapsed time only while active.

This helper inherits Waybar's unit and stdout. The Bash CLI owns status semantics;
Gio keeps Subscribe and signal matches on the same D-Bus connection.
"""

import json
import os
import signal
import subprocess
import sys
import time

sys.dont_write_bytecode = True

try:
    from gi.repository import Gio, GLib, GLibUnix
except ImportError:
    subprocess.run(
        ["custom-i18n", "get", "cli_dependency", "name=python-gobject"],
        stdout=sys.stderr,
        check=False,
    )
    sys.exit(127)

UNIT = "custom-record.service"
BUS = "org.freedesktop.systemd1"
MANAGER_PATH = "/org/freedesktop/systemd1"
MANAGER = f"{BUS}.Manager"
UNIT_PATH = f"{MANAGER_PATH}/unit/custom_2drecord_2eservice"
PROPERTIES = "org.freedesktop.DBus.Properties"
TICK_MS = 1000
QUERY_TIMEOUT = 5
STATE_PROPERTIES = {"ActiveState", "SubState", "MainPID", "Result", "Environment"}


def translate(key, *values):
    return subprocess.check_output(
        ["custom-i18n", "get", key, *values], text=True, timeout=QUERY_TIMEOUT
    ).strip()


class Watcher:
    def __init__(self, command):
        self.command = command
        self.loop = GLib.MainLoop()
        self.timer = 0
        self.pending = 0
        self.error = None
        self.snapshot = {}
        self.previous = None
        self.started = 0.0
        self.templates = {
            "recording": translate("record_running_record", "duration={duration}"),
            "live": translate("record_running_stream", "duration={duration}"),
        }
        self.idle = {
            "text": "",
            "alt": "idle",
            "class": "idle",
            "tooltip": translate("record_idle"),
            "elapsed": 0,
        }
        self.connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.connection.set_exit_on_close(False)
        self.closed_handler = self.connection.connect("closed", self.disconnected)
        self.matches = [
            self.connection.signal_subscribe(
                BUS,
                PROPERTIES,
                "PropertiesChanged",
                UNIT_PATH,
                None,
                Gio.DBusSignalFlags.NONE,
                self.changed,
            ),
            self.connection.signal_subscribe(
                BUS,
                MANAGER,
                None,
                MANAGER_PATH,
                None,
                Gio.DBusSignalFlags.NONE,
                self.unit_changed,
            ),
            self.connection.signal_subscribe(
                "org.freedesktop.DBus",
                "org.freedesktop.DBus",
                "NameOwnerChanged",
                "/org/freedesktop/DBus",
                BUS,
                Gio.DBusSignalFlags.NONE,
                self.disconnected,
            ),
        ]
        # Keep this connection alive: a short-lived busctl call would unsubscribe
        # as soon as it exits. Subscribe before the initial query to avoid gaps.
        self.connection.call_sync(
            BUS,
            MANAGER_PATH,
            MANAGER,
            "Subscribe",
            None,
            None,
            Gio.DBusCallFlags.NONE,
            QUERY_TIMEOUT * 1000,
            None,
        )

    def disconnected(self, *_args):
        self.error = ConnectionError(BUS)
        self.loop.quit()

    def changed(self, _conn, _sender, _path, _interface, _member, parameters):
        interface, changed, invalidated = parameters.unpack()
        if interface in (f"{BUS}.Unit", f"{BUS}.Service") and (
            STATE_PROPERTIES.intersection(changed)
            or STATE_PROPERTIES.intersection(invalidated)
        ):
            self.queue_refresh()

    def unit_changed(self, _conn, _sender, _path, _interface, member, parameters):
        if member in ("UnitNew", "UnitRemoved") and parameters.unpack()[0] == UNIT:
            self.queue_refresh()

    def queue_refresh(self):
        if not self.pending:
            self.pending = GLib.idle_add(self.refresh)

    def unit_loaded(self):
        # Unlike `systemctl show`, GetUnit does not load an absent unit. Querying
        # an absent transient unit would cause a UnitNew/UnitRemoved feedback loop.
        try:
            path = self.connection.call_sync(
                BUS,
                MANAGER_PATH,
                MANAGER,
                "GetUnit",
                GLib.Variant("(s)", (UNIT,)),
                None,
                Gio.DBusCallFlags.NONE,
                QUERY_TIMEOUT * 1000,
                None,
            ).unpack()[0]
            loaded = self.connection.call_sync(
                BUS,
                path,
                PROPERTIES,
                "Get",
                GLib.Variant("(ss)", (f"{BUS}.Unit", "LoadState")),
                None,
                Gio.DBusCallFlags.NONE,
                QUERY_TIMEOUT * 1000,
                None,
            ).unpack()[0]
            return loaded != "not-found"
        except GLib.Error as exc:
            if Gio.DBusError.get_remote_error(exc) in (
                f"{BUS}.NoSuchUnit",
                "org.freedesktop.DBus.Error.UnknownObject",
            ):
                return False
            raise

    def refresh(self):
        self.pending = 0
        if self.timer:
            GLib.source_remove(self.timer)
            self.timer = 0
        try:
            sampled = time.monotonic()
            if self.unit_loaded():
                self.snapshot = json.loads(
                    subprocess.check_output(
                        [self.command, "status", "waybar"],
                        text=True,
                        timeout=QUERY_TIMEOUT,
                    )
                )
            else:
                self.snapshot = self.idle
            self.started = sampled - self.snapshot["elapsed"]
            self.emit()
            if self.snapshot["alt"] in self.templates:
                self.timer = GLib.timeout_add(TICK_MS, self.tick)
        except (
            GLib.Error,
            OSError,
            ValueError,
            KeyError,
            subprocess.SubprocessError,
        ) as exc:
            self.error = exc
            self.loop.quit()
        return GLib.SOURCE_REMOVE

    def emit(self):
        payload = self.snapshot.copy()
        if payload["alt"] in self.templates:
            elapsed = max(0, int(time.monotonic() - self.started))
            duration = f"{elapsed // 60:02d}:{elapsed % 60:02d}"
            payload.update(
                text=duration,
                elapsed=elapsed,
                tooltip=self.templates[payload["alt"]].replace("{duration}", duration),
            )
        if payload != self.previous:
            print(json.dumps(payload, ensure_ascii=False), flush=True)
            self.previous = payload

    def tick(self):
        try:
            self.emit()
        except (OSError, ValueError) as exc:
            self.error = exc
            self.loop.quit()
            self.timer = 0
            return GLib.SOURCE_REMOVE
        return GLib.SOURCE_CONTINUE

    def run(self):
        self.queue_refresh()
        try:
            self.loop.run()
        finally:
            if self.timer:
                GLib.source_remove(self.timer)
            if self.pending:
                GLib.source_remove(self.pending)
            for match in self.matches:
                self.connection.signal_unsubscribe(match)
            # Closing the process's connection also releases Manager.Subscribe.
            self.connection.disconnect(self.closed_handler)
            if not self.connection.is_closed():
                self.connection.close_sync(None)
        if self.error:
            raise self.error


def main():
    try:
        watcher = Watcher(sys.argv[1])
        for signum in (signal.SIGTERM, signal.SIGINT):
            GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signum, watcher.loop.quit)
        watcher.run()
    except BrokenPipeError:
        # Waybar closed its pipe (reload or exit); no diagnostic/retry is needed.
        with open(os.devnull, "w") as sink:
            os.dup2(sink.fileno(), sys.stdout.fileno())
    except (GLib.Error, OSError, ValueError, KeyError, subprocess.SubprocessError):
        subprocess.run(
            ["custom-i18n", "get", "cli_unavailable", "name=custom-record:watch"],
            stdout=sys.stderr,
            check=False,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
