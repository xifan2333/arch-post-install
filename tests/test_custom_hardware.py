from test_custom_cli import BIN, CliTest


class HardwareTest(CliTest):
    def setUp(self):
        super().setUp()
        script = self.bin / "custom-hardware"
        script.unlink()
        script.write_text(
            (BIN / "custom-hardware")
            .read_text()
            .replace("/sys/", str(self.base / "sys") + "/")
            .replace("/proc/", str(self.base / "proc") + "/")
        )
        script.chmod(0o755)
        self.gpu = self.base / "sys/class/drm/card3"
        self.gpu.mkdir(parents=True)
        for node, value in [
            ("cur", 700),
            ("min", 350),
            ("max", 1400),
            ("RPn", 350),
            ("RP0", 1400),
        ]:
            (self.gpu / f"gt_{node}_freq_mhz").write_text(str(value))

    def test_real_limits_are_used_without_fabricated_values(self):
        self.run_cli("hardware", "gpu", "max")
        self.assertEqual((self.gpu / "gt_min_freq_mhz").read_text(), "1400\n")
        self.run_cli("hardware", "gpu", "auto")
        self.assertEqual((self.gpu / "gt_min_freq_mhz").read_text(), "350\n")
        (self.gpu / "gt_RP0_freq_mhz").unlink()
        self.run_cli("hardware", "gpu", "max", code=1)
        self.assertEqual((self.gpu / "gt_min_freq_mhz").read_text(), "350\n")

    def test_invalid_reading_fails_without_partial_status(self):
        (self.gpu / "gt_max_freq_mhz").write_text("unreadable")
        result = self.run_cli("hardware", "gpu", "status", code=1)
        self.assertEqual(result.stdout, "")
        self.run_cli("hardware", "fan", "status", code=1)

    def test_unwritable_node_does_not_try_privilege_rescue(self):
        node = self.gpu / "gt_min_freq_mhz"
        node.chmod(0o444)
        calls = self.base / "privilege-calls"
        self.fake("pkexec", f"touch '{calls}'")
        self.fake("sudo", f"touch '{calls}'")
        self.run_cli("hardware", "gpu", "max", code=1)
        self.assertFalse(calls.exists())
        self.assertEqual(node.read_text(), "350")
