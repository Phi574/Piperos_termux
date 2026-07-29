#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

fail() {
    echo "Configuration error: $*" >&2
    exit 1
}

[[ "$PIPEROS_APP_PACKAGE_NAME" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]] ||
    fail "invalid Android application id"
[[ "$PIPEROS_MIN_API" =~ ^[0-9]+$ ]] || fail "minimum API must be numeric"
((PIPEROS_MIN_API >= 24)) || fail "minimum API must be at least 24"
[[ "$PIPEROS_RUNTIME_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[a-z0-9.-]+$ ]] ||
    fail "runtime version must resemble 2.5.0-beta.1"
[[ "$PIPEROS_BOOTSTRAP_ADDITIONAL_PACKAGES" =~ ^[a-z0-9+._-]+(,[a-z0-9+._-]+)*$ ]] ||
    fail "additional bootstrap packages must be a comma-separated package list"
[[ "$PIPEROS_APT_REPOSITORY_URL" =~ ^https://[^/]+(/[^/]+)*$ ]] ||
    fail "APT repository URL must be an HTTPS URL without a trailing slash"
[[ "$PIPEROS_APT_SUITE" =~ ^[a-z0-9][a-z0-9.-]*$ ]] ||
    fail "APT suite contains unsupported characters"
[[ "$PIPEROS_APT_COMPONENT" =~ ^[a-z0-9][a-z0-9.-]*$ ]] ||
    fail "APT component contains unsupported characters"
[[ "$PIPEROS_APT_KEY_FINGERPRINT" =~ ^[0-9A-F]{40}$ ]] ||
    fail "APT signing key fingerprint must contain 40 uppercase hex characters"
[[ -s "$PIPEROS_REPO_ROOT/keys/apt-repository-public.gpg" ]] ||
    fail "APT repository public key is missing"
require_command gpg
apt_key_fingerprint="$(
    gpg --batch --with-colons --show-keys \
        "$PIPEROS_REPO_ROOT/keys/apt-repository-public.gpg" |
        awk -F: '$1 == "fpr" { print $10; exit }'
)"
[[ "$apt_key_fingerprint" == "$PIPEROS_APT_KEY_FINGERPRINT" ]] ||
    fail "APT repository public key does not match its pinned fingerprint"
[[ "$TERMUX_PACKAGES_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
    fail "upstream revision must be a full 40-character commit"

IFS=',' read -r -a android_abis <<<"$PIPEROS_ANDROID_ABIS"
[[ "${#android_abis[@]}" -eq 3 ]] || fail "exactly three Android ABIs are required"
for abi in "${android_abis[@]}"; do
    termux_arch_for_android_abi "$abi" >/dev/null
done

[[ "$PIPEROS_PREFIX" == "/data/data/com.piper.os.tool/files/usr" ]] ||
    fail "prefix does not match the PiperOS application id"

echo "PiperOS runtime configuration is valid."
printf '  application id: %s\n' "$PIPEROS_APP_PACKAGE_NAME"
printf '  prefix:         %s\n' "$PIPEROS_PREFIX"
printf '  Android ABIs:   %s\n' "$PIPEROS_ANDROID_ABIS"
printf '  APT repository: %s\n' "$PIPEROS_APT_REPOSITORY_URL"
printf '  APT key:        %s\n' "$PIPEROS_APT_KEY_FINGERPRINT"
