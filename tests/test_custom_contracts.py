import json
import shutil

from test_custom_cli import BIN, CliTest


class ContractTest(CliTest):
    def restrict_path(self):
        self.env["PATH"] = str(self.bin)
        for name in ["bash", "jq", "cat", "head", "dirname", "rm", "mktemp", "id"]:
            (self.bin / name).symlink_to(shutil.which(name))

    def test_missing_dependencies_exit_127_without_alternatives(self):
        self.restrict_path()
        title = self.base / "state/custom-stream-title/history.txt"
        title.parent.mkdir(parents=True)
        title.write_text("title\n")
        font = self.base / "state/font/fonts.conf"
        font.parent.mkdir(parents=True)
        font.write_text("<fontconfig/>")
        image = self.base / "image.png"
        image.write_bytes(b"image")
        for name, args in [
            ("audio", ["list"]),
            ("capture", ["full"]),
            ("clipboard", ["list"]),
            ("font", ["current"]),
            ("keystrokes", ["start"]),
            ("ocr", ["-"]),
            ("power", ["lock"]),
            ("power", ["logout"]),
            ("record", ["status"]),
            ("stream-title", ["start"]),
            ("wallhaven", ["search", "test"]),
            ("wallpaper", ["set", str(image)]),
        ]:
            result = self.run_cli(name, *args, input="image", code=127)
            self.assertEqual(result.stdout, "")
        self.assertFalse((self.base / "pictures").exists())
        self.assertFalse((self.base / "videos").exists())

    def test_help_only_needs_the_translation_client(self):
        self.restrict_path()
        for source in BIN.glob("custom-*"):
            self.run_cli(source.name.removeprefix("custom-"), "--help")
        self.assertFalse((self.base / "state").exists())

    def test_missing_jq_is_not_a_successful_translation(self):
        self.restrict_path()
        (self.bin / "jq").unlink()
        self.run_cli("i18n", "--help")
        self.run_cli("i18n", "get", "domain_audio", code=127)

    def test_title_and_font_validate_before_writing(self):
        self.run_cli("stream-title", "set", "", code=2)
        self.run_cli("stream-title", "set", "a\nb", code=2)
        self.run_cli("font", "init", "", "CJK", code=2)
        self.run_cli("font", "set", "a\nb", code=2)
        self.run_cli("wallpaper", "set", "/not/a/file.png", code=2)
        self.assertFalse((self.base / "state").exists())
        self.assertFalse((self.base / "pictures").exists())

    def test_dictionaries_have_matching_keys(self):
        dictionaries = [
            json.loads((self.base / f"config/i18n/{language}.json").read_text())
            for language in ["en-us", "zh-cn"]
        ]
        self.assertEqual(dictionaries[0].keys(), dictionaries[1].keys())
