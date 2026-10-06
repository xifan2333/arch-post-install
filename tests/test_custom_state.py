import subprocess

from test_custom_cli import ROOT, CliTest


class StateTest(CliTest):
    def test_title_get_is_empty_without_creating_state(self):
        legacy = self.base / "data/custom-stream-title/history.txt"
        legacy.parent.mkdir(parents=True)
        legacy.write_text("old title\n")
        self.assertEqual(self.run_cli("stream-title", "get").stdout, "")
        self.run_cli("stream-title", "start", code=1)
        self.assertFalse((self.base / "state").exists())

    def test_title_cancel_and_picker_failure(self):
        self.fake("fuzzel", "exit 1")
        self.run_cli("stream-title", "edit")
        self.assertFalse((self.base / "state").exists())
        self.fake("fuzzel", "exit 2")
        self.run_cli("stream-title", "edit", code=1)

    def test_migration_preserves_order_and_special_titles(self):
        paths = [
            self.base / "state/custom-stream-title/history.txt",
            self.base / "data/custom-stream-title/history.txt",
            self.base / "state/wayhud/title_history.txt",
        ]
        for path, content in zip(
            paths,
            ["latest\nA & B\n", "other\nlatest\n", "  old  \nA & B\n"],
            strict=True,
        ):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        for _ in range(2):
            subprocess.run(
                ["bash", str(ROOT / "scripts/migrations/336-title-state.sh")],
                env=self.env,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertEqual(paths[0].read_text(), "latest\nA & B\nother\n  old  \n")
        self.assertFalse(paths[1].exists())
        self.assertFalse(paths[2].exists())

    def test_font_init_preserves_authority_and_repairs_derivatives(self):
        self.fake("fc-list", "printf '%s\\n' 'Mono & One' 'CJK Two' 'Other'")
        self.run_cli("font", "init", "Mono & One", "CJK Two")
        state = self.base / "state/font"
        authority = (state / "fonts.conf").read_bytes()
        self.assertIn(b"Mono &amp; One", authority)
        (state / "waybar.css").unlink()
        self.run_cli("font", "init", "Other", "Other")
        self.assertEqual((state / "fonts.conf").read_bytes(), authority)
        self.assertIn('"Mono & One", "CJK Two"', (state / "waybar.css").read_text())
        self.assertEqual(self.run_cli("font", "current", "mono").stdout, "Mono & One\n")

    def test_bad_authority_is_never_overwritten(self):
        state = self.base / "state/font"
        state.mkdir(parents=True)
        (state / "fonts.conf").write_text("<broken>")
        self.fake("fc-list", "printf '%s\\n' Mono CJK")
        self.run_cli("font", "init", "Mono", "CJK", code=1)
        self.assertEqual((state / "fonts.conf").read_text(), "<broken>")

    def test_font_read_and_cancel_do_not_create_state(self):
        self.run_cli("font", "--help")
        self.run_cli("font", "current", code=1)
        self.run_cli("font", "arbitrary-font", code=2)
        self.fake("fc-list", "exit 0")
        self.assertEqual(self.run_cli("font", "list").stdout, "")
        self.assertFalse((self.base / "state").exists())

    def test_font_names_keep_xml_and_css_special_characters(self):
        self.fake("fc-list", "printf '%s\\n' 'Mono/\"One\" & Two' 'CJK'")
        self.run_cli("font", "init", 'Mono/"One" & Two', "CJK")
        self.assertEqual(
            self.run_cli("font", "current", "mono").stdout, 'Mono/"One" & Two\n'
        )
        css = (self.base / "state/font/waybar.css").read_text()
        self.assertIn(r"Mono/\"One\" & Two", css)

    def test_font_second_picker_cancellation_keeps_the_selection(self):
        self.fake("fc-list", "printf '%s\\n' Mono CJK")
        self.run_cli("font", "init", "Mono", "CJK")
        authority = self.base / "state/font/fonts.conf"
        before = authority.read_bytes()
        self.env["PICK_COUNT"] = str(self.base / "picker-count")
        self.fake(
            "fuzzel",
            """cat >/dev/null
if [[ -e "$PICK_COUNT" ]]; then exit 1; fi
touch "$PICK_COUNT"
printf 0""",
        )
        self.run_cli("font", "menu")
        self.assertEqual(authority.read_bytes(), before)
