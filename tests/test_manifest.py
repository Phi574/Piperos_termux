# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import importlib.util
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ManifestTests(unittest.TestCase):
    def test_supported_abis_match_runtime_config(self) -> None:
        spec = importlib.util.spec_from_file_location(
            "generate_manifest", ROOT / "scripts" / "generate-manifest.py"
        )
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        runtime = (ROOT / "config" / "runtime.env").read_text(encoding="utf-8")
        match = re.search(r"^PIPEROS_ANDROID_ABIS=(.+)$", runtime, re.MULTILINE)
        self.assertIsNotNone(match)
        configured = set(match.group(1).split(","))
        self.assertEqual(configured, set(module.ABI_TO_TERMUX_ARCH))

    def test_package_id_and_prefix_are_pinned(self) -> None:
        runtime = (ROOT / "config" / "runtime.env").read_text(encoding="utf-8")
        self.assertIn("PIPEROS_APP_PACKAGE_NAME=com.piper.os.tool", runtime)
        generator = (ROOT / "scripts" / "generate-manifest.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("/data/data/com.piper.os.tool/files/usr", generator)

    def test_generate_and_verify_partial_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            archive = temp / "piperos-bootstrap-arm64-v8a-2.5.0-beta.1.zip"
            archive.write_bytes(b"test bootstrap")
            manifest = temp / "runtime-manifest.json"

            subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts" / "generate-manifest.py"),
                    "--input",
                    str(temp),
                    "--output",
                    str(manifest),
                    "--base-url",
                    "https://example.invalid/release",
                    "--allow-partial",
                ],
                check=True,
            )
            subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts" / "verify-manifest.py"),
                    str(manifest),
                    "--assets-dir",
                    str(temp),
                ],
                check=True,
            )

            payload = json.loads(manifest.read_text(encoding="utf-8"))
            self.assertEqual(payload["applicationId"], "com.piper.os.tool")
            self.assertEqual(payload["assets"]["arm64-v8a"]["termuxArch"], "aarch64")



if __name__ == "__main__":
    unittest.main()
