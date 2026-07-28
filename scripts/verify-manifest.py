#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--assets-dir", type=Path, required=True)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest["applicationId"] != "com.piper.os.tool":
        raise SystemExit("Unexpected application id")
    if manifest["prefix"] != "/data/data/com.piper.os.tool/files/usr":
        raise SystemExit("Unexpected prefix")

    for abi, asset in manifest["assets"].items():
        path = args.assets_dir / asset["fileName"]
        if not path.is_file():
            raise SystemExit(f"Missing {abi} archive: {path}")
        if path.stat().st_size != asset["size"]:
            raise SystemExit(f"Size mismatch for {abi}")
        if digest(path) != asset["sha256"]:
            raise SystemExit(f"SHA-256 mismatch for {abi}")

    print("Runtime manifest and local assets are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

