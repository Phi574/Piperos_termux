# PiperOS package repository

The PiperOS APT repository contains packages compiled specifically for:

```text
application id: com.piper.os.tool
prefix:         /data/data/com.piper.os.tool/files/usr
```

Packages from the official Termux repository must not be mixed with this
runtime because their embedded prefix and application identity differ.

## Package set

The direct packages are declared in `config/package-set.txt`. Build
dependencies are resolved and compiled from the pinned Termux package source.
The initial set contains Python, Git, OpenSSH and the `libllvm` source recipe,
which emits the user-facing Clang package.

Validate the list:

```bash
./scripts/validate-package-set.py config/package-set.txt
```

Build one architecture:

```bash
./scripts/build-package-set.sh arm64-v8a
./scripts/build-package-set.sh armeabi-v7a
./scripts/build-package-set.sh x86_64
```

Assemble downloaded architecture artifacts into a repository:

```bash
sudo apt-get install apt-utils dpkg-dev gnupg xz-utils
./scripts/assemble-apt-repository.sh \
  dist/package-input \
  dist/apt-repository
```

## Repository layout

The generated repository follows the standard APT layout:

```text
dists/stable/Release
dists/stable/InRelease
dists/stable/Release.gpg
dists/stable/main/binary-aarch64/Packages.xz
dists/stable/main/binary-arm/Packages.xz
dists/stable/main/binary-x86_64/Packages.xz
pool/main/*.deb
piperos-archive-keyring.gpg
```

The production endpoint is:

```text
https://phi574.github.io/Piperos_termux
```

Pinned signing-key fingerprint:

```text
322C E397 F439 E57D 589F  C2EC 700F 8680 4882 BE7E
```

## Signing setup

Create a dedicated OpenPGP signing key on an offline trusted machine:

```bash
gpg --batch --quick-generate-key \
  "PiperOS Package Repository <packages@piperos.local>" \
  rsa4096 sign 2y
gpg --armor --export-secret-keys \
  "PiperOS Package Repository" |
  base64 -w 0
```

Store the base64 output in the GitHub Actions secret
`PIPEROS_APT_SIGNING_KEY_B64`. Keep an offline backup of the private key.
Never commit it. The public key is committed as
`keys/apt-repository-public.gpg`.

Manual workflow runs create an unsigned preview artifact when the secret is
not configured. A production `packages-v*` tag requires the signing secret,
creates `InRelease` and `Release.gpg`, exports the public key, and deploys the
repository to GitHub Pages.

## Client configuration

Install the public key into the PiperOS prefix:

```bash
mkdir -p "$PREFIX/etc/apt/keyrings"
cp piperos-archive-keyring.gpg \
  "$PREFIX/etc/apt/keyrings/piperos-archive-keyring.gpg"
```

Create `$PREFIX/etc/apt/sources.list.d/piperos.list`:

```text
deb [signed-by=/data/data/com.piper.os.tool/files/usr/etc/apt/keyrings/piperos-archive-keyring.gpg] https://phi574.github.io/Piperos_termux stable main
```

Then refresh and install packages:

```bash
pkg update
pkg install python git openssh clang
```

The Android installer should provision the pinned public key and source file
during runtime installation. It must not use `trusted=yes`.
