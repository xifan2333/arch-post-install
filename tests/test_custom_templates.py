import json
import os
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from test_custom_cli import ROOT


class TemplateTest(unittest.TestCase):
    def test_mise_renders_absolute_state_paths_and_reapplies(self):
        with tempfile.TemporaryDirectory(prefix="custom-template-test-") as directory:
            base = Path(directory)
            config = base / "mise.toml"
            files = ["fontconfig/fonts.conf", "fuzzel/fuzzel.ini", "waybar/style.css"]
            entries = ["[dotfiles]"]
            for name in files:
                source = ROOT / f"dotfiles/.config/{name}.tera"
                entries.append(
                    f"{json.dumps(str(base / 'output' / name))} = "
                    f'{{ source = {json.dumps(str(source))}, mode = "template" }}'
                )
            config.write_text("\n".join(entries))
            env = dict(os.environ)
            env.update(
                XDG_CONFIG_HOME=str(base / "config"),
                XDG_STATE_HOME=str(base / "state & fonts"),
                MISE_DATA_DIR=str(base / "mise-data"),
                MISE_STATE_DIR=str(base / "mise-state"),
                MISE_TRUSTED_CONFIG_PATHS=str(base),
                MISE_NO_HOOKS="1",
            )
            mise = shutil.which("mise")
            self.assertIsNotNone(mise)
            for state in ["state & fonts", "new state"]:
                env["XDG_STATE_HOME"] = str(base / state)
                result = subprocess.run(
                    [mise, "--cd", str(base), "dotfiles", "apply", "--yes"],
                    env=env,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                fontconfig = ET.parse(base / "output/fontconfig/fonts.conf")
                self.assertEqual(
                    fontconfig.find("include").text,
                    str(base / state / "font/fonts.conf"),
                )
                fuzzel = (base / "output/fuzzel/fuzzel.ini").read_text()
                self.assertIn(f"include={base / state}/font/fuzzel.ini", fuzzel)
                css = (base / "output/waybar/style.css").read_text()
                self.assertIn(str(base / state / "font/waybar.css"), css)
                self.assertNotIn("{{", css)
