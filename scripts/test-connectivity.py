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
STATION = "/net/connman/iwd/0/1"
NETWORK = STATION + "/test_psk"
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
    elif operation == "call" and args[4] == "GetOrderedNetworks":
        print(json.dumps({"data": [f["ordered"]]}))
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
        if not f.get("no_effect"):
            if args[3] == "net.connman.iwd.Station":
                objects[path][args[3]]["State"] = {"data": "disconnected"}
                for device in objects.values():
                    if "net.connman.iwd.Network" in device:
                        device["net.connman.iwd.Network"]["Connected"] = {"data": False}
            else:
                objects[path][args[3]]["Connected"] = {"data": args[4] == "Connect"}
        p.write_text(json.dumps(f))
    elif operation == "call" and args[4] in ("StartDiscovery", "StopDiscovery", "Scan"):
        pass
    else:
        print("unexpected D-Bus call", file=sys.stderr)
        sys.exit(90)
elif name == "fuzzel":
    sys.stdin.read()
    if f.get("menu_exit"):
        sys.exit(f["menu_exit"])
    if "--password" in args:
        if f.get("password_exit"):
            sys.exit(f["password_exit"])
        print(f.get("password", "test-password"))
    else:
        print(f.get("selection", "1"))
elif name == "iwctl":
    if f.get("iwctl_fail"):
        print("fixture authentication failure", file=sys.stderr)
        sys.exit(7)
    for device in f["net.connman.iwd"].values():
        props = device.get("net.connman.iwd.Network", {})
        if props.get("Name", {}).get("data") == args[-1]:
            props["Connected"] = {"data": True}
    p.write_text(json.dumps(f))
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
            "iwctl",
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
            },
            "net.connman.iwd": {
                STATION: {
                    "net.connman.iwd.Device": props(Name="wlan0"),
                    "net.connman.iwd.Station": props(
                        State="disconnected", ConnectedNetwork=""
                    ),
                },
                NETWORK: {
                    "net.connman.iwd.Network": props(
                        Name="Test WiFi",
                        Type="psk",
                        Connected=False,
                        KnownNetwork="/net/connman/iwd/test_psk",
                    )
                },
            },
            "ordered": [[NETWORK, -5000]],
        }

    def run_cli(self, script, *args, stdin=""):
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
            input=stdin,
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

    def test_wifi_queries_and_help_do_not_mutate(self):
        for action in ("list", "status", "--help"):
            with self.subTest(action=action):
                result = self.run_cli("x-wifi", action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.mutations(), [])
                self.assertFalse(any(c[0] == "fuzzel" for c in self.recorded()))
                if action == "--help":
                    self.assertEqual(self.recorded(), [])

    def test_wifi_bad_arguments_do_not_query_devices(self):
        for args in (
            ("unknown",),
            ("connect",),
            ("status", "extra"),
            ("connect", "ssid", "--bad"),
        ):
            with self.subTest(args=args):
                result = self.run_cli("x-wifi", *args)
                self.assertEqual(result.returncode, 2)
                self.assertIn("Usage:", result.stderr)
                self.assertEqual(self.recorded(), [])

    def test_wifi_connect_saved_and_open_networks(self):
        net = self.fixture["net.connman.iwd"][NETWORK]["net.connman.iwd.Network"]
        for kind in ("saved", "open"):
            with self.subTest(kind=kind):
                if kind == "open":
                    net.update(props(Type="open", KnownNetwork=""))
                result = self.run_cli("x-wifi", "connect", "Test WiFi")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "connected\tTest WiFi\n")
                self.assertEqual([c[-1] for c in self.mutations()], ["Connect"])
                self.assertFalse(any(c[0] == "fuzzel" for c in self.recorded()))

    def test_wifi_connect_already_connected(self):
        self.fixture["net.connman.iwd"][NETWORK]["net.connman.iwd.Network"].update(
            props(Connected=True)
        )
        result = self.run_cli("x-wifi", "connect", "Test WiFi")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [])

    def test_wifi_unknown_network_and_credentials_do_not_open_menu(self):
        self.fixture["net.connman.iwd"][NETWORK]["net.connman.iwd.Network"].update(
            props(KnownNetwork="")
        )
        for name in ("Missing", "Test WiFi"):
            with self.subTest(name=name):
                result = self.run_cli("x-wifi", "connect", name)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
                self.assertEqual(self.mutations(), [])
                self.assertFalse(any(c[0] == "fuzzel" for c in self.recorded()))

    def test_wifi_cli_and_menu_preserve_ssid_and_passphrase(self):
        ssid = " O'Brien $USER `false` $(false) \\ WiFi\t"
        password = "a'b $USER `false` $(false) \\ pass "
        net = self.fixture["net.connman.iwd"][NETWORK]["net.connman.iwd.Network"]
        net.update(props(Name=ssid, KnownNetwork=""))
        self.fixture["password"] = password
        for args in (("connect", ssid, "--passphrase-stdin"), ("menu",)):
            with self.subTest(args=args):
                result = self.run_cli("x-wifi", *args, stdin=password + "\n")
                self.assertEqual(result.returncode, 0, result.stderr)
                call = next(c for c in self.recorded() if c[0] == "iwctl")
                self.assertEqual(
                    call,
                    [
                        "iwctl",
                        "--dont-ask",
                        "--passphrase",
                        password,
                        "station",
                        "wlan0",
                        "connect",
                        ssid,
                    ],
                )
                self.assertNotIn(password, result.stdout + result.stderr)

    def test_wifi_failures_propagate_without_forgetting_credentials(self):
        for method in ("GetManagedObjects", "GetOrderedNetworks", "Connect"):
            with self.subTest(method=method):
                self.fixture["fail"] = method
                result = self.run_cli("x-wifi", "connect", "Test WiFi")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertIn("fixture D-Bus failure", result.stderr)
                self.assertFalse(any("Forget" in c for c in self.recorded()))
        self.fixture.pop("fail")
        self.fixture["iwctl_fail"] = True
        result = self.run_cli(
            "x-wifi", "connect", "Test WiFi", "--passphrase-stdin", stdin="wrong\n"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture authentication failure", result.stderr)

    def test_wifi_disconnected_is_not_a_connected_substring(self):
        self.fixture["no_effect"] = True
        result = self.run_cli("x-wifi", "connect", "Test WiFi")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertFalse(any("Forget" in c for c in self.recorded()))

    def test_wifi_disconnect_failure_and_idempotence(self):
        result = self.run_cli("x-wifi", "disconnect")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [])
        self.fixture["net.connman.iwd"][STATION]["net.connman.iwd.Station"].update(
            props(State="connected", ConnectedNetwork=NETWORK)
        )
        self.fixture["fail"] = "Disconnect"
        result = self.run_cli("x-wifi", "disconnect")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_wifi_toggle_does_not_fall_back_to_menu(self):
        self.fixture["net.connman.iwd"][NETWORK]["net.connman.iwd.Network"].update(
            props(KnownNetwork="")
        )
        result = self.run_cli("x-wifi", "toggle")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.mutations(), [])
        self.assertFalse(any(c[0] == "fuzzel" for c in self.recorded()))
        self.fixture["net.connman.iwd"][NETWORK]["net.connman.iwd.Network"].update(
            props(KnownNetwork="/known")
        )
        result = self.run_cli("x-wifi", "toggle")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[-1] for c in self.mutations()], ["Connect"])

    def test_wifi_menu_cancel_password_cancel_and_missing_menu(self):
        self.fixture["menu_exit"] = 1
        result = self.run_cli("x-wifi", "menu")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [])
        self.fixture.pop("menu_exit")
        self.fixture["password_exit"] = 1
        self.fixture["net.connman.iwd"][NETWORK]["net.connman.iwd.Network"].update(
            props(KnownNetwork="")
        )
        result = self.run_cli("x-wifi", "menu")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(c[0] == "iwctl" for c in self.recorded()))
        (self.bin / "fuzzel").unlink()
        result = self.run_cli("x-wifi", "menu")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.mutations(), [])

    def test_wifi_empty_passphrase(self):
        result = self.run_cli("x-wifi", "connect", "Test WiFi", "--passphrase-stdin")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.mutations(), [])


if __name__ == "__main__":
    unittest.main()
