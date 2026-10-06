import json
import subprocess
import sys

from test_custom_cli import CliTest


class DomainTest(CliTest):
    def setUp(self):
        super().setUp()
        (self.base / "runtime").mkdir()
        self.calls = self.base / "calls"
        self.env["CALLS"] = str(self.calls)
        for name in ["notify-send", "wl-copy", "hyprlock", "xrwm", "systemctl", "uwsm"]:
            self.fake(name, 'printf "%s\\n" "$0 $*" >> "$CALLS"')

    def audio_fixture(self):
        data = [
            {
                "id": i,
                "info": {
                    "props": {
                        "media.class": "Audio/Sink",
                        "node.name": f"sink-{i}",
                        "node.description": name,
                    }
                },
            }
            for i, name in [(52, "Built-in"), (61, "USB DAC (2024)")]
        ]
        self.fake("pw-dump", "cat <<'EOF'\n" + json.dumps(data) + "\nEOF")
        self.fake(
            "wpctl",
            """if [[ "$1" == inspect ]]; then
printf 'id 52, type PipeWire:Interface:Node\n';
else printf '%s\n' "$*" >> "$CALLS"; fi""",
        )

    def test_audio_index_maps_to_id_with_digits_in_name(self):
        self.audio_fixture()
        self.fake("fuzzel", "cat >/dev/null; printf '1'")
        self.run_cli("audio")
        self.assertIn("set-default 61\n", self.calls.read_text())
        self.assertNotIn("set-default 2024", self.calls.read_text())

    def test_audio_empty_and_failures_are_different(self):
        self.fake("pw-dump", "printf '[]'")
        self.fake("wpctl", "exit 91")
        self.assertEqual(self.run_cli("audio", "list").stdout, "")
        self.fake("pw-dump", "exit 4")
        self.run_cli("audio", "list", code=1)
        self.fake("pw-dump", "printf 'bad json'")
        self.run_cli("audio", "current", code=1)
        self.audio_fixture()
        self.fake("wpctl", "exit 5")
        self.run_cli("audio", "current", code=1)

    def test_menu_cancellation_never_applies_first_item(self):
        self.audio_fixture()
        self.fake("cliphist", "printf '1\\tSample'")
        self.fake("fuzzel", "cat >/dev/null; exit 1")
        for domain in [
            "audio",
            "power",
            "capture",
            "clipboard",
            "wallpaper",
            "wallhaven",
        ]:
            self.run_cli(domain)
        self.assertFalse(self.calls.exists())
        for directory in ["state", "pictures", "videos"]:
            self.assertFalse((self.base / directory).exists())
        self.fake("fuzzel", "exit 2")
        self.run_cli("power", "menu", code=1)

    def test_capture_explicit_path_and_stream(self):
        self.fake(
            "grim",
            """if [[ "${!#}" == - ]]; then printf image;
else printf image > "${!#}"; fi""",
        )
        self.run_cli("capture", "full", "-o", code=2)
        self.run_cli("capture", "full", "-o", "path", "extra", code=2)
        self.assertEqual(self.run_cli("capture", "full", "-o", "-").stdout, "image")
        self.assertFalse(self.calls.exists())
        path = self.base / "images/a file (2024).png"
        self.assertEqual(
            self.run_cli("capture", "full", "-o", str(path)).stdout, f"{path}\n"
        )
        self.assertEqual(path.read_bytes(), b"image")

    def test_capture_failure_does_not_replace_file_or_clipboard(self):
        path = self.base / "previous.png"
        path.write_bytes(b"old image")
        self.fake("grim", "exit 5")
        self.run_cli("capture", "full", "-o", str(path), code=1)
        self.assertEqual(path.read_bytes(), b"old image")
        self.assertFalse(self.calls.exists())
        self.assertEqual(list(self.base.glob(".capture.*")), [])

    def test_area_cancel_and_slurp_error_are_distinct(self):
        self.fake("grim", "exit 99")
        self.fake("slurp", "exit 1")
        self.run_cli("capture", "area")
        self.assertFalse((self.base / "pictures").exists())
        self.fake("slurp", "echo 'cannot connect' >&2; exit 1")
        self.run_cli("capture", "area", code=1)

    def test_ocr_does_not_hide_backend_or_json_failure(self):
        self.fake("nbocr", "exit 3")
        self.run_cli("ocr", "-", input="image", code=1)
        self.fake("nbocr", '''printf 'bad json' > "${!#}"''')
        self.run_cli("ocr", "-", input="image", code=1)
        self.fake("nbocr", '''printf '{"results": []}' > "${!#}"''')
        self.assertEqual(self.run_cli("ocr", "-", input="image").stdout, "")
        self.assertEqual(list((self.base / "runtime").iterdir()), [])

    def test_clipboard_decode_failure_keeps_clipboard(self):
        self.fake("fuzzel", "cat >/dev/null; printf 1")
        self.fake(
            "cliphist",
            """if [[ "$1" == list ]]; then printf '1\tentry'; else exit 3; fi""",
        )
        self.run_cli("clipboard", "menu", code=1)
        self.assertFalse(self.calls.exists())

    def test_wallhaven_network_error_and_empty_results(self):
        self.fake("curl", "exit 22")
        self.run_cli("wallhaven", "search", "a & b", code=1)
        self.fake("curl", "printf '{\"data\": []}'")
        self.assertEqual(self.run_cli("wallhaven", "search", "a & b").stdout, "")
        self.fake("curl", "printf '{}'")
        self.run_cli("wallhaven", "search", "test", code=1)
        self.assertFalse((self.base / "pictures").exists())

    def test_wallhaven_file_output_is_explicit_and_atomic(self):
        path = self.base / "image file.png"
        path.write_text("old")
        self.fake("curl", "exit 22")
        self.run_cli(
            "wallhaven",
            "download",
            "https://example.test/image.png",
            "-o",
            str(path),
            code=1,
        )
        self.assertEqual(path.read_text(), "old")
        self.fake(
            "curl",
            """while (( $# )); do
if [[ "$1" == -o ]]; then printf image > "$2"; exit; fi
shift
done
printf image""",
        )
        self.assertEqual(
            self.run_cli("wallhaven", "download", "https://example.test/a").stdout,
            "image",
        )
        self.assertEqual(
            self.run_cli(
                "wallhaven", "download", "https://example.test/a", "-o", str(path)
            ).stdout,
            f"{path}\n",
        )
        self.assertEqual(path.read_text(), "image")

    def test_wallpaper_uses_explicit_download_file(self):
        self.fake(
            "custom-wallhaven",
            '''[[ "$1" == download && "$3" == -o ]] || exit 92
printf image > "$4"
printf '%s\n' "$4"''',
        )
        self.fake("magick", "printf PNG")
        self.fake("swaybg", "exit 99")
        self.fake("pgrep", "exit 1")
        result = self.run_cli("wallpaper", "set", "abc123")
        self.assertTrue(result.stdout.strip().endswith(".png"))
        self.assertIn("-t service", self.calls.read_text())
        self.assertEqual(list((self.base / "runtime").iterdir()), [])

    def test_wallpaper_current_reads_nul_argv_and_never_guesses_file(self):
        wall = self.base / "pictures/wallpapers/wallpaper.png"
        wall.parent.mkdir(parents=True)
        wall.write_text("old image")
        self.fake("pgrep", "exit 1")
        self.assertEqual(self.run_cli("wallpaper", "current").stdout, "")
        path = str(self.base / "a wallpaper (2024).png")
        process = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(20)", "-i", path]
        )
        self.addCleanup(process.wait)
        self.addCleanup(process.terminate)
        self.fake("pgrep", f"printf {process.pid}")
        self.assertEqual(self.run_cli("wallpaper", "current").stdout, f"{path}\n")

    def test_bad_arguments_and_help_have_no_desktop_dependencies(self):
        for domain in [
            "audio",
            "capture",
            "clipboard",
            "hardware",
            "keystrokes",
            "power",
            "wallhaven",
            "wallpaper",
        ]:
            self.run_cli(domain, "--help")
            self.run_cli(domain, "unexpected-action", code=2)
            self.run_cli(domain, "--help", "extra", code=2)
        self.run_cli("audio", "list", "arbitrary-mode", code=2)
        self.run_cli("hardware", "gpu", "100garbage", code=2)
        self.run_cli("wallhaven", "download", "abc123", "-o", code=2)
        self.assertFalse(self.calls.exists())
