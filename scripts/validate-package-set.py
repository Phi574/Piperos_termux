#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import argparse
import re
from pathlib import Path


PACKAGE_NAME = re.compile(r"^[a-z0-9][a-z0-9+.-]*$")
REPOSITORY_DIRS = ("packages", "root-packages", "x11-packages")


def read_package_set(path: Path) -> list[str]:
    packages: list[str] = []
    seen: set[str] = set()

    for line_number, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        package = raw_line.split("#", 1)[0].strip()
        if not package:
            continue
        if not PACKAGE_NAME.fullmatch(package):
            raise ValueError(
                f"{path}:{line_number}: invalid package name {package!r}"
            )
        if package in seen:
            raise ValueError(
                f"{path}:{line_number}: duplicate package {package!r}"
            )
        seen.add(package)
        packages.append(package)

    if not packages:
        raise ValueError(f"{path}: package set is empty")
    return packages


def validate_recipes(packages: list[str], upstream: Path) -> None:
    missing = [
        package
        for package in packages
        if not any(
            (upstream / repository / package / "build.sh").is_file()
            for repository in REPOSITORY_DIRS
        )
    ]
    if missing:
        raise ValueError(
            "package recipes not found in pinned upstream: " + ", ".join(missing)
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate and print the PiperOS package set."
    )
    parser.add_argument("package_set", type=Path)
    parser.add_argument("--upstream", type=Path)
    parser.add_argument(
        "--print",
        action="store_true",
        dest="print_packages",
        help="Print one validated package name per line.",
    )
    args = parser.parse_args()

    try:
        packages = read_package_set(args.package_set)
        if args.upstream is not None:
            validate_recipes(packages, args.upstream)
    except (OSError, ValueError) as error:
        parser.error(str(error))

    if args.print_packages:
        print("\n".join(packages))
    else:
        print(f"Package set is valid ({len(packages)} packages).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
