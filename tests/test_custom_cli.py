"""Isolated CLI contracts; no desktop, network, or hardware mutations."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / "dotfiles/.local/bin"


class CliTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="custom-cli-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ)
        self.env.update(
            PATH=f"{self.bin}:/usr/bin:/bin",
            LC_ALL="C",
            XDG_CONFIG_HOME=str(self.base / "config"),
            XDG_STATE_HOME=str(self.base / "state"),
            XDG_DATA_HOME=str(self.base / "data"),
            XDG_RUNTIME_DIR=str(self.base / "runtime"),
            XDG_PICTURES_DIR=str(self.base / "pictures"),
            XDG_VIDEOS_DIR=str(self.base / "videos"),
        )
        for source in BIN.glob("custom-*"):
            (self.bin / source.name).symlink_to(source)
        shutil.copytree(ROOT / "dotfiles/.config/i18n", self.base / "config/i18n")

    def fake(self, name, body):
        path = self.bin / name
        if path.is_symlink():
            path.unlink()
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def run_cli(self, name, *args, input="", code=0):
        result = subprocess.run(
            [str(self.bin / f"custom-{name}"), *args],
            input=input,
            capture_output=True,
            text=True,
            env=self.env,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, code, result.stderr)
        return result


class I18nTest(CliTest):
    def test_missing_dictionary_has_no_repo_or_english_fallback(self):
        self.env["LC_ALL"] = "zh_CN.UTF-8"
        (self.base / "config/i18n/zh-cn.json").unlink()
        result = self.run_cli("i18n", "get", "domain_audio", code=1)
        self.assertEqual(result.stdout, "")
        self.assertIn("dictionary", result.stderr)

    def test_missing_key_and_bad_json_fail(self):
        self.run_cli("i18n", "get", "nonexistent_key", code=1)
        (self.base / "config/i18n/en-us.json").write_text("{")
        self.run_cli("i18n", "get", "domain_audio", code=1)

    def test_unsupported_locale(self):
        self.env["LC_ALL"] = "fr_FR.UTF-8"
        self.run_cli("i18n", "current", code=1)

    def test_args_validate_before_dictionary(self):
        shutil.rmtree(self.base / "config")
        for args in [
            ("wat",),
            ("get",),
            ("current", "extra"),
            ("get", "a", "bad"),
            ("list", "wat"),
        ]:
            self.run_cli("i18n", *args, code=2)
        self.run_cli("i18n", "--help")

    def test_substitution_and_env_preserve_literal_shell_text(self):
        value = '$HOME `id` "quotes" \\ newline\n&value'
        dictionary = {"key": "Hello {name}", "odd'key": value}
        (self.base / "config/i18n/en-us.json").write_text(json.dumps(dictionary))
        result = self.run_cli("i18n", "get", "key", f"name={value}")
        self.assertEqual(result.stdout, f"Hello {value}\n")
        declarations = self.run_cli("i18n", "env").stdout
        result = subprocess.run(
            ["bash", "-c", declarations + '\nprintf "%s" "${i18n["odd\'key"]}"'],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(result.stdout, value)


if __name__ == "__main__":
    unittest.main()
