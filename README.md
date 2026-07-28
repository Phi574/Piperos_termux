# PiperOS Termux Runtime

PiperOS Termux Runtime builds an on-device terminal environment for the
PiperOS Android application. Runtime archives and packages are compiled for
the PiperOS application id and cannot be mixed with official Termux packages.

## Runtime contract

| Setting | Value |
| --- | --- |
| Android application id | `com.piper.os.tool` |
| Minimum Android API | `24` |
| Root filesystem | `/data/data/com.piper.os.tool/files` |
| Home | `/data/data/com.piper.os.tool/files/home` |
| Prefix | `/data/data/com.piper.os.tool/files/usr` |

Supported Android ABIs:

| Android ABI | Termux architecture |
| --- | --- |
| `arm64-v8a` | `aarch64` |
| `armeabi-v7a` | `arm` |
| `x86_64` | `x86_64` |

## Build

Linux with Docker is required. The build scripts clone a pinned revision of
[`termux/termux-packages`](https://github.com/termux/termux-packages), patch
its application id before compilation, and build every dependency from
source.

```bash
./scripts/validate-config.sh
./scripts/build-bootstrap.sh arm64-v8a
./scripts/build-bootstrap.sh armeabi-v7a
./scripts/build-bootstrap.sh x86_64
./scripts/generate-manifest.py \
  --input dist \
  --output dist/runtime-manifest.json \
  --base-url https://github.com/Phi574/Piperos_termux/releases/download/runtime-v2.5.0-beta.1
```

The first build is intentionally expensive. Packages compiled for
`com.termux` cannot be used as build dependencies because their embedded
prefix differs from PiperOS.

## GitHub Actions

- `Validate repository` checks shell scripts, Python scripts, configuration,
  licensing files, and manifest generation.
- `Build bootstrap archives` builds the three supported ABIs. Manual runs
  retain build artifacts. A tag matching `runtime-v*` additionally creates a
  signed GitHub Release.

Before creating the first runtime tag, add the repository secret
`PIPEROS_MANIFEST_SIGNING_KEY_B64`. Its value is the base64 encoding of the
PEM Ed25519 private key matching `keys/manifest-public.pem`.

```bash
base64 -w 0 manifest-private.pem
git tag runtime-v2.5.0-beta.1
git push origin runtime-v2.5.0-beta.1
```

Never commit the private key.

## Package set

The initial optional package set is stored in
[`config/package-set.txt`](config/package-set.txt). Python, Git, OpenSSH and
Clang remain optional packages so the first bootstrap download stays small.
A dedicated signed APT repository workflow will be added after the bootstrap
has completed successfully for all three architectures.

## Licensing

This repository is licensed under GNU GPL version 3 only. See
[`LICENSE`](LICENSE), [`COPYRIGHT`](COPYRIGHT), and
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Termux contains components under multiple licenses. In particular,
`terminal-emulator` and `terminal-view` are Apache-2.0, while Termux-specific
application code is GPL-3.0-only. Preserve upstream notices and file-level
license exceptions when copying or modifying upstream source.

