# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_validator():
    spec = importlib.util.spec_from_file_location(
        "validate_package_set", ROOT / "scripts" / "validate-package-set.py"
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PackageSetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.validator = load_validator()

    def test_project_package_set(self) -> None:
        packages = self.validator.read_package_set(
            ROOT / "config" / "package-set.txt"
        )
        self.assertEqual(packages, ["python", "git", "openssh", "libllvm"])

    def test_comments_and_inline_comments(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package_set = Path(directory) / "packages.txt"
            package_set.write_text(
                "# tools\npython  # language\nopenssh\n",
                encoding="utf-8",
            )
            self.assertEqual(
                self.validator.read_package_set(package_set),
                ["python", "openssh"],
            )

    def test_duplicate_package_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package_set = Path(directory) / "packages.txt"
            package_set.write_text("git\ngit\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicate package"):
                self.validator.read_package_set(package_set)

    def test_invalid_package_name_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package_set = Path(directory) / "packages.txt"
            package_set.write_text("not a package\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "invalid package name"):
                self.validator.read_package_set(package_set)


if __name__ == "__main__":
    unittest.main()
