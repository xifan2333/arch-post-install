import re
import subprocess
import unittest

from test_custom_cli import BIN, ROOT


class ConsumerTest(unittest.TestCase):
    def test_retired_aliases_and_consumer_references_are_gone(self):
        suffixes = [
            "audio",
            "cap",
            "clip",
            "font",
            "hw",
            "i18n",
            "keys",
            "ocr",
            "power",
            "rec",
            "title",
            "wall",
            "wallhaven",
        ]
        pattern = re.compile(r"\bx" + "-(" + "|".join(suffixes) + r")\b")
        for suffix in suffixes:
            path = BIN / ("x" + "-" + suffix)
            self.assertFalse(path.exists() or path.is_symlink(), str(path))
        paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT, text=True)
        for relative in paths.split("\0"):
            path = ROOT / relative
            if not path.is_file() or path.is_symlink():
                continue
            try:
                content = path.read_text()
            except UnicodeDecodeError:
                continue
            self.assertIsNone(pattern.search(content), relative)

    def test_record_menu_consumers_are_explicit(self):
        self.assertIn(
            "G spawn custom-record menu",
            (ROOT / "dotfiles/.config/xrwm/bindings").read_text(),
        )
        self.assertIn(
            '"on-click-right": "custom-record menu"',
            (ROOT / "dotfiles/.config/waybar/config").read_text(),
        )
