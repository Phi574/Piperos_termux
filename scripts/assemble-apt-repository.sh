#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

INPUT_DIR="${1:-$PIPEROS_REPO_ROOT/dist/packages}"
OUTPUT_DIR="${2:-$PIPEROS_REPO_ROOT/dist/apt-repository}"

for command in apt-ftparchive base64 dpkg-deb dpkg-scanpackages gzip gpg \
    sha256sum tar xz; do
    require_command "$command"
done

[[ -d "$INPUT_DIR" ]] ||
    { echo "Package input directory not found: $INPUT_DIR" >&2; exit 66; }

mkdir -p "$OUTPUT_DIR/pool/$PIPEROS_APT_COMPONENT"
pool_dir="$OUTPUT_DIR/pool/$PIPEROS_APT_COMPONENT"

while IFS= read -r -d '' package_file; do
    package_name="$(basename "$package_file")"
    destination="$pool_dir/$package_name"
    if [[ -f "$destination" ]]; then
        existing_hash="$(sha256sum "$destination" | cut -d' ' -f1)"
        incoming_hash="$(sha256sum "$package_file" | cut -d' ' -f1)"
        [[ "$existing_hash" == "$incoming_hash" ]] ||
            { echo "Conflicting package file: $package_name" >&2; exit 1; }
        continue
    fi
    cp "$package_file" "$destination"
done < <(find "$INPUT_DIR" -type f -name '*.deb' -print0)

package_count="$(find "$pool_dir" -maxdepth 1 -type f -name '*.deb' | wc -l)"
((package_count > 0)) || { echo "No .deb packages found" >&2; exit 1; }

while IFS= read -r -d '' package_file; do
    architecture="$(dpkg-deb --field "$package_file" Architecture)"
    [[ "$architecture" =~ ^(aarch64|arm|x86_64|all)$ ]] || {
        echo "Unsupported package architecture '$architecture': $package_file" >&2
        exit 1
    }

    invalid_path="$(
        dpkg-deb --fsys-tarfile "$package_file" |
            tar -tf - |
            grep -Ev \
                '^(\./)?(data(/data(/com\.piper\.os\.tool(/files(/(usr|home)(/.*)?)?)?)?)?)?/?$' |
            head -n 1 || true
    )"
    [[ -z "$invalid_path" ]] || {
        echo "Package contains a path outside PiperOS runtime: $invalid_path" >&2
        exit 1
    }
done < <(find "$pool_dir" -maxdepth 1 -type f -name '*.deb' -print0)

architectures=(aarch64 arm x86_64)
for architecture in "${architectures[@]}"; do
    binary_dir="$OUTPUT_DIR/dists/$PIPEROS_APT_SUITE/$PIPEROS_APT_COMPONENT/binary-$architecture"
    mkdir -p "$binary_dir"
    (
        cd "$OUTPUT_DIR"
        dpkg-scanpackages --arch "$architecture" \
            "pool/$PIPEROS_APT_COMPONENT" /dev/null \
            >"dists/$PIPEROS_APT_SUITE/$PIPEROS_APT_COMPONENT/binary-$architecture/Packages"
    )
    gzip -9cn "$binary_dir/Packages" >"$binary_dir/Packages.gz"
    xz -9e -c "$binary_dir/Packages" >"$binary_dir/Packages.xz"
done

release_dir="$OUTPUT_DIR/dists/$PIPEROS_APT_SUITE"
(
    cd "$OUTPUT_DIR"
    apt-ftparchive \
        -o "APT::FTPArchive::Release::Origin=PiperOS" \
        -o "APT::FTPArchive::Release::Label=PiperOS" \
        -o "APT::FTPArchive::Release::Suite=$PIPEROS_APT_SUITE" \
        -o "APT::FTPArchive::Release::Codename=$PIPEROS_APT_SUITE" \
        -o "APT::FTPArchive::Release::Architectures=aarch64 arm x86_64" \
        -o "APT::FTPArchive::Release::Components=$PIPEROS_APT_COMPONENT" \
        -o "APT::FTPArchive::Release::Description=PiperOS package repository" \
        release "dists/$PIPEROS_APT_SUITE" \
        >"dists/$PIPEROS_APT_SUITE/Release"
)

if [[ -n "${PIPEROS_APT_SIGNING_KEY_B64:-}" ]]; then
    signing_home="$(mktemp -d)"
    trap 'rm -rf "$signing_home"' EXIT
    chmod 700 "$signing_home"
    printf '%s' "$PIPEROS_APT_SIGNING_KEY_B64" |
        base64 --decode |
        gpg --batch --homedir "$signing_home" --import
    fingerprint="$(
        gpg --batch --homedir "$signing_home" --with-colons \
            --list-secret-keys |
            awk -F: '$1 == "fpr" { print $10; exit }'
    )"
    [[ "$fingerprint" == "$PIPEROS_APT_KEY_FINGERPRINT" ]] || {
        echo "APT signing key does not match pinned public key" >&2
        exit 1
    }

    gpg --batch --yes --homedir "$signing_home" \
        --local-user "$fingerprint" \
        --armor --detach-sign \
        --output "$release_dir/Release.gpg" \
        "$release_dir/Release"
    gpg --batch --yes --homedir "$signing_home" \
        --local-user "$fingerprint" \
        --armor --clearsign \
        --output "$release_dir/InRelease" \
        "$release_dir/Release"
    cp "$PIPEROS_REPO_ROOT/keys/apt-repository-public.gpg" \
        "$OUTPUT_DIR/piperos-archive-keyring.gpg"
elif [[ "${PIPEROS_REQUIRE_APT_SIGNATURE:-false}" == "true" ]]; then
    echo "Missing PIPEROS_APT_SIGNING_KEY_B64 for production publish" >&2
    exit 1
else
    echo "Created unsigned repository preview; production publish requires signing."
fi

cat >"$OUTPUT_DIR/index.html" <<EOF
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>PiperOS Package Repository</title></head>
<body>
<h1>PiperOS Package Repository</h1>
<p>Suite: $PIPEROS_APT_SUITE. Component: $PIPEROS_APT_COMPONENT.</p>
<p>Source: <a href="https://github.com/Phi574/Piperos_termux">Piperos_termux</a>.</p>
</body>
</html>
EOF

(
    cd "$OUTPUT_DIR"
    checksum_file="$(mktemp)"
    find . -type f ! -name SHA256SUMS -print0 |
        sort -z |
        xargs -0 sha256sum >"$checksum_file"
    mv "$checksum_file" SHA256SUMS
)

echo "Created APT repository with $package_count package files at $OUTPUT_DIR"
