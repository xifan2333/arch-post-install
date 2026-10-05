#!/usr/bin/env -S PYTHONDONTWRITEBYTECODE=1 python3
"""Exercise desktop connectivity CLIs with real Lua/shell/jq and fake devices."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = "/org/bluez/hci0"
DEVICE = ADAPTER + "/dev_00_11_22_33_44_55"
MAC = "00:11:22:33:44:55"
LUA = shutil.which("luajit") or shutil.which("lua")

# Every external desktop/device command resolves to this fixture executable.
# PATH contains only the stubs and explicitly allowed language/text tools.
STUB = r"""
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
p = Path(os.environ["CONNECTIVITY_FIXTURE"])
f = json.loads(p.read_text())
with open(os.environ["CONNECTIVITY_CALLS"], "a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "busctl":
    args = [a for a in args if not a.startswith("--")]
    if f.get("fail") and f["fail"] in args:
        print("fixture D-Bus failure", file=sys.stderr)
        sys.exit(7)
    operation, service, path = args[:3]
    objects = f[service]
    if operation == "call" and args[4] == "GetManagedObjects":
        print(json.dumps({"data": [objects]}))
    elif operation == "get-property":
        value = objects[path][args[3]][args[4]]["data"]
        if isinstance(value, bool):
            print("b " + str(value).lower())
        else:
            print("s " + json.dumps(value))
    elif operation == "set-property":
        objects[path][args[3]][args[4]] = {"data": args[6] == "true"}
        p.write_text(json.dumps(f))
    elif operation == "call" and args[4] in ("Connect", "Disconnect"):
        objects[path][args[3]]["Connected"] = {"data": args[4] == "Connect"}
        p.write_text(json.dumps(f))
    elif operation == "call" and args[4] in ("StartDiscovery", "StopDiscovery"):
        pass
    else:
        print("unexpected D-Bus call", file=sys.stderr)
        sys.exit(90)
elif name == "fuzzel":
    sys.stdin.read()
    if f.get("menu_exit"):
        sys.exit(f["menu_exit"])
    print(f.get("selection", "1"))
elif name == "bluetoothctl":
    if f.get("pair_fail"):
        sys.exit(7)
    for device in f["org.bluez"].values():
        props = device.get("org.bluez.Device1", {})
        if props.get("Address", {}).get("data") == args[-1]:
            props["Paired"] = {"data": True}
    p.write_text(json.dumps(f))
elif name == "timeout":
    os.execvp(args[1], args[1:])
elif name in ("notify-send", "sleep"):
    sys.exit(f.get("notify_exit", 0) if name == "notify-send" else 0)
else:
    print("unexpected fixture command", file=sys.stderr)
    sys.exit(91)
"""


def props(**values):
    return {key: {"data": value} for key, value in values.items()}


class ConnectivityTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="connectivity-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.config = self.base / "fixture.json"
        self.calls = self.base / "calls.jsonl"
        for name in ("bash", "jq", "python3"):
            executable = shutil.which(name)
            self.assertIsNotNone(executable, f"required test tool: {name}")
            (self.bin / name).symlink_to(executable)
        (self.bin / "x-i18n").symlink_to(ROOT / "dotfiles/.local/bin/x-i18n")
        for name in (
            "busctl",
            "fuzzel",
            "bluetoothctl",
            "notify-send",
            "timeout",
            "sleep",
        ):
            path = self.bin / name
            path.write_text(f"#!{sys.executable}\n" + STUB)
            path.chmod(0o755)
        self.env = dict(
            os.environ,
            PATH=str(self.bin),
            LC_ALL="C",
            XDG_CONFIG_HOME=str(ROOT / "dotfiles/.config"),
            XDG_RUNTIME_DIR=str(self.base),
            CONNECTIVITY_FIXTURE=str(self.config),
            CONNECTIVITY_CALLS=str(self.calls),
            PYTHONDONTWRITEBYTECODE="1",
        )
        self.fixture = {
            "org.bluez": {
                ADAPTER: {"org.bluez.Adapter1": props(Powered=True, Pairable=False)},
                DEVICE: {
                    "org.bluez.Device1": props(
                        Address=MAC,
                        Alias="Test Headset",
                        Connected=True,
                        Paired=True,
                        Icon="audio-card",
                    )
                },
            }
        }

    def run_cli(self, script, *args):
        self.assertIsNotNone(LUA, "install luajit or lua to run these tests")
        self.config.write_text(json.dumps(self.fixture))
        self.calls.write_text("")
        return subprocess.run(
            [LUA, str(ROOT / "dotfiles/.local/bin" / script), *args],
            env=self.env,
            text=True,
            capture_output=True,
            timeout=10,
            check=False,
        )

    def recorded(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def mutations(self):
        return [
            call
            for call in self.recorded()
            if call[0] == "busctl"
            and (
                "set-property" in call
                or any(
                    method in call
                    for method in ("Connect", "Disconnect", "RemoveDevice", "Forget")
                )
            )
        ]

    def test_blue_queries_do_not_power_or_pair(self):
        self.fixture["org.bluez"][ADAPTER]["org.bluez.Adapter1"]["Powered"]["data"] = (
            False
        )
        for action in ("status", "list", "devices"):
            with self.subTest(action=action):
                result = self.run_cli("x-blue", action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.mutations(), [])
                self.assertFalse(any(c[0] == "fuzzel" for c in self.recorded()))
                if action == "status":
                    self.assertIn("powered: off", result.stdout)

    def test_blue_help_and_bad_args_do_not_query_devices(self):
        for args, code in (
            (["--help"], 0),
            (["unknown"], 2),
            (["connect"], 2),
            (["status", "extra"], 2),
        ):
            with self.subTest(args=args):
                result = self.run_cli("x-blue", *args)
                self.assertEqual(result.returncode, code)
                self.assertEqual(self.recorded(), [])
                self.assertIn("Usage:", result.stdout if code == 0 else result.stderr)

    def test_blue_repeated_connect_is_idempotent(self):
        result = self.run_cli("x-blue", "connect", MAC)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, f"connected\t{MAC}\n")
        self.assertEqual(self.mutations(), [])

    def test_blue_connect_is_noninteractive(self):
        self.fixture["org.bluez"][DEVICE]["org.bluez.Device1"]["Connected"]["data"] = (
            False
        )
        result = self.run_cli("x-blue", "connect", MAC)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[-1] for c in self.mutations()], ["Connect"])
        self.assertFalse(
            any(
                c[0] in ("fuzzel", "notify-send", "bluetoothctl")
                for c in self.recorded()
            )
        )

    def test_blue_failures_propagate(self):
        for method, action in (
            ("GetManagedObjects", "status"),
            ("Disconnect", "disconnect"),
            ("Powered", "off"),
        ):
            with self.subTest(method=method):
                self.fixture["fail"] = method
                result = self.run_cli("x-blue", action)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertIn("fixture D-Bus failure", result.stderr)

    def test_blue_disconnect_already_disconnected(self):
        self.fixture["org.bluez"][DEVICE]["org.bluez.Device1"]["Connected"]["data"] = (
            False
        )
        result = self.run_cli("x-blue", "disconnect", MAC)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [])

    def test_blue_name_and_notification_remain_literal(self):
        name = "  O'Brien $USER `false` $(false) \\ headset\t\n"
        self.fixture["org.bluez"][DEVICE]["org.bluez.Device1"]["Alias"]["data"] = name
        result = self.run_cli("x-blue", "connect", name)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_cli("x-blue", "menu")
        self.assertEqual(result.returncode, 0, result.stderr)
        notification = next(c for c in self.recorded() if c[0] == "notify-send")
        self.assertEqual(notification[-1], f"Disconnected: {name}")

    def test_blue_menu_cancel_and_missing_menu(self):
        self.fixture["menu_exit"] = 1
        result = self.run_cli("x-blue", "menu")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(
            any(c[-1] in ("Connect", "Disconnect") for c in self.mutations())
        )
        (self.bin / "fuzzel").unlink()
        result = self.run_cli("x-blue", "menu")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.mutations(), [])

    def test_blue_menu_phone_only_pairs(self):
        device = self.fixture["org.bluez"][DEVICE]["org.bluez.Device1"]
        device.update(props(Connected=False, Paired=False, Icon="phone"))
        result = self.run_cli("x-blue", "menu")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, f"paired\t{MAC}\n")
        self.assertTrue(any(c[0] == "bluetoothctl" for c in self.recorded()))
        self.assertFalse(any(c[-1] == "Connect" for c in self.mutations()))


if __name__ == "__main__":
    unittest.main()
