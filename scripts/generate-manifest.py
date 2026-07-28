#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

ABI_TO_TERMUX_ARCH = {
    "arm64-v8a": "aarch64",
    "armeabi-v7a": "arm",
    "x86_64": "x86_64",
}
ARCHIVE_PATTERN = re.compile(
    r"^piperos-bootstrap-(arm64-v8a|armeabi-v7a|x86_64)-(.+)\.zip$"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--allow-partial", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    assets: dict[str, dict[str, object]] = {}
    versions: set[str] = set()

    for archive in sorted(args.input.glob("piperos-bootstrap-*.zip")):
        match = ARCHIVE_PATTERN.match(archive.name)
        if not match:
            continue
        abi, version = match.groups()
        versions.add(version)
        assets[abi] = {
            "termuxArch": ABI_TO_TERMUX_ARCH[abi],
            "fileName": archive.name,
            "url": f"{args.base_url.rstrip('/')}/{quote(archive.name)}",
            "sha256": sha256(archive),
            "size": archive.stat().st_size,
        }

    if len(versions) != 1:
        raise SystemExit(f"Expected one runtime version, found: {sorted(versions)}")
    missing = sorted(set(ABI_TO_TERMUX_ARCH) - set(assets))
    if missing and not args.allow_partial:
        raise SystemExit(f"Missing runtime archives: {', '.join(missing)}")

    manifest = {
        "schema": 1,
        "runtimeVersion": next(iter(versions)),
        "applicationId": "com.piper.os.tool",
        "minApi": 24,
        "rootfs": "/data/data/com.piper.os.tool/files",
        "home": "/data/data/com.piper.os.tool/files/home",
        "prefix": "/data/data/com.piper.os.tool/files/usr",
        "createdAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "source": {
            "repository": os.environ.get(
                "GITHUB_SERVER_URL", "https://github.com"
            )
            + "/"
            + os.environ.get("GITHUB_REPOSITORY", "Phi574/Piperos_termux"),
            "revision": os.environ.get("GITHUB_SHA", "development"),
        },
        "assets": assets,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, ensure_ascii=True, indent=2) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

