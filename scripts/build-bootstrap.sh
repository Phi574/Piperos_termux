#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ANDROID_ABI="${1:-}"
TERMUX_ARCH="$(termux_arch_for_android_abi "$ANDROID_ABI")"
UPSTREAM_DIR="$PIPEROS_REPO_ROOT/.work/termux-packages"
DIST_DIR="$PIPEROS_REPO_ROOT/dist"

require_command docker
"$SCRIPT_DIR/validate-config.sh"
"$SCRIPT_DIR/prepare-upstream.sh" "$UPSTREAM_DIR"

mkdir -p "$DIST_DIR"
rm -f "$UPSTREAM_DIR"/bootstrap-"$TERMUX_ARCH".zip

builder_path="$PATH"
if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    # GitHub-hosted runners expose AppArmor tooling but do not allow the
    # upstream helper to replace its restricted profile. Hiding sbin skips
    # that host-only profile step inside an isolated, ephemeral runner.
    builder_path="/usr/local/bin:/usr/bin:/bin"
fi

(
    cd "$UPSTREAM_DIR"
    PATH="$builder_path" CI=true CONTAINER_NAME="piperos-termux-$TERMUX_ARCH" \
        ./scripts/run-docker.sh \
        ./scripts/build-bootstraps.sh \
        -f \
        --architectures "$TERMUX_ARCH"
)

source_archive="$UPSTREAM_DIR/bootstrap-$TERMUX_ARCH.zip"
target_archive="$DIST_DIR/piperos-bootstrap-$ANDROID_ABI-$PIPEROS_RUNTIME_VERSION.zip"

[[ -s "$source_archive" ]] ||
    { echo "Bootstrap archive was not created: $source_archive" >&2; exit 1; }
cp "$source_archive" "$target_archive"

sha256sum "$target_archive" >"$target_archive.sha256"
echo "Created $target_archive"
