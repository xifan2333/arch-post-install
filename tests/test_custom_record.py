import json
import subprocess

from test_custom_cli import CliTest


class RecordTest(CliTest):
    def setUp(self):
        super().setUp()
        (self.base / "runtime").mkdir()
        self.state = self.base / "unit-state"
        self.calls = self.base / "calls"
        self.env.update(
            REC_STATE=str(self.state),
            CALLS=str(self.calls),
            REC_LOCK=str(self.base / "unit-lock"),
        )
        self.unit_state()
        self.fake(
            "systemctl",
            """
case "$2" in
show) cat "$REC_STATE" ;;
stop)
printf 'stop\n' >> "$CALLS"
printf 'LoadState=not-found
ActiveState=inactive
SubState=dead
MainPID=0
Result=success
' > "$REC_STATE"
;;
reset-failed) printf 'reset\n' >> "$CALLS" ;;
*) exit 99 ;;
esac""",
        )
        self.fake(
            "systemd-run",
            """
mkdir "$REC_LOCK" || exit 1
printf '%s\n' "$@" >> "$CALLS"
if [[ "${START_FAIL:-}" == yes ]]; then
printf 'LoadState=loaded
ActiveState=failed
SubState=failed
MainPID=0
Result=exit-code
' > "$REC_STATE"
exit 1
fi
printf 'LoadState=loaded
ActiveState=active
SubState=running
MainPID=345
Result=success
' > "$REC_STATE"
""",
        )
        self.fake("gpu-screen-recorder", "exit 99")
        self.fake("notify-send", 'printf "notified\\n" >> "$CALLS"')
        self.fake("pgrep", "exit 99")
        self.fake("pkill", "exit 1")
        self.fake("ps", "printf ' 125'")

    def unit_state(self, active="inactive", result="success"):
        loaded = "not-found" if active == "inactive" else "loaded"
        sub = {"active": "running", "inactive": "dead"}.get(active, active)
        pid = 345 if active == "active" else 0
        self.state.write_text(
            f"LoadState={loaded}\nActiveState={active}\nSubState={sub}\n"
            f"MainPID={pid}\nResult={result}\n"
        )

    def test_default_is_status_without_directory_creation(self):
        self.assertEqual(self.run_cli("record").stdout, "idle\n")
        result = self.run_cli("record", "status", "waybar")
        self.assertEqual(json.loads(result.stdout)["class"], "idle")
        self.run_cli("record", "stop")
        self.assertFalse(self.calls.exists())
        self.assertFalse((self.base / "videos").exists())

    def test_running_duration_comes_from_unit_pid(self):
        self.unit_state("active")
        self.assertEqual(self.run_cli("record").stdout, "recording (02:05)\n")
        self.fake("ps", "exit 1")
        self.run_cli("record", "status", code=1)

    def test_failed_unit_is_visible_and_toggle_does_not_restart(self):
        self.unit_state("failed", "exit-code")
        result = self.run_cli("record", "status", "waybar", code=1)
        self.assertEqual(json.loads(result.stdout)["class"], "failed")
        self.run_cli("record", "toggle", code=1)
        self.run_cli("record", "stop", code=1)
        self.assertFalse(self.calls.exists())

    def test_start_is_named_exec_service_and_stop_uses_its_signal_policy(self):
        self.run_cli("record", "full")
        calls = self.calls.read_text()
        for arg in [
            "--unit=custom-record.service",
            "--service-type=exec",
            "--property=KillSignal=SIGINT",
            "--expand-environment=no",
        ]:
            self.assertIn(arg, calls)
        self.assertNotIn("--collect", calls)
        self.run_cli("record", "full", code=1)
        self.assertEqual(self.calls.read_text(), calls)
        self.run_cli("record", "stop")
        self.assertIn("stop\n", self.calls.read_text())
        self.assertEqual(self.run_cli("record").stdout, "idle\n")

    def test_area_cancel_preserves_failed_service(self):
        self.unit_state("failed", "exit-code")
        before = self.state.read_bytes()
        self.fake("slurp", "exit 1")
        self.run_cli("record", "area")
        self.assertEqual(self.state.read_bytes(), before)
        self.assertFalse(self.calls.exists())
        self.assertFalse((self.base / "videos").exists())

    def test_area_uses_region_arguments(self):
        self.fake("slurp", "printf '800x600+10+20'")
        self.run_cli("record", "area")
        self.assertIn("-w\nregion\n-region\n800x600+10+20\n", self.calls.read_text())

    def test_exec_failure_is_preserved_without_success_notification(self):
        self.env["START_FAIL"] = "yes"
        self.run_cli("record", "full", code=1)
        self.assertNotIn("notified", self.calls.read_text())
        self.run_cli("record", "status", code=1)
        self.assertIn("ActiveState=failed", self.state.read_text())

    def test_explicit_start_resets_previous_failure(self):
        self.unit_state("failed", "exit-code")
        self.run_cli("record", "full")
        self.assertTrue(self.calls.read_text().startswith("reset\n"))

    def test_concurrent_starts_create_only_one_service(self):
        command = [str(self.bin / "custom-record"), "full"]
        processes = [
            subprocess.Popen(
                command,
                env=self.env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            for _ in range(2)
        ]
        for process in processes:
            process.communicate(timeout=10)
        self.assertEqual(sorted(p.returncode for p in processes), [0, 1])
        self.assertEqual(
            self.calls.read_text().count("--unit=custom-record.service"), 1
        )

    def test_invalid_status_format_and_service_query_failure(self):
        self.run_cli("record", "status", "nonsense", code=2)
        self.fake("systemctl", "exit 1")
        self.run_cli("record", "--help")
        self.run_cli("record", code=1)
        self.assertFalse((self.base / "videos").exists())
