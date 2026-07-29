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
    # upstream helper to replace its restricted profile. Use Docker's
    # unconfined profile only inside the isolated, ephemeral CI runner and
    # hide sbin so the upstream helper does not try to load another profile.
    sed -i \
        "s/--security-opt apparmor=_custom-termux-package-builder-\$CONTAINER_NAME/--security-opt apparmor=unconfined/" \
        "$UPSTREAM_DIR/scripts/run-docker.sh"
    builder_path="/usr/local/bin:/usr/bin:/bin"

    if [[ "$TERMUX_ARCH" == "x86_64" ]]; then
        # LLVM's x86 backend has the highest peak linker memory use. Keeping
        # two workers prevents the hosted runner from killing a compiler
        # process while still allowing the long build to make progress.
        export TERMUX_DOCKER_EXEC_EXTRA_ARGS="${TERMUX_DOCKER_EXEC_EXTRA_ARGS:-} --env TERMUX_PKG_MAKE_PROCESSES=2"
        echo "PiperOS x86_64 memory guard: TERMUX_PKG_MAKE_PROCESSES=2"
    fi
fi

(
    cd "$UPSTREAM_DIR"
    PATH="$builder_path" CI=true CONTAINER_NAME="piperos-termux-$TERMUX_ARCH" \
        ./scripts/run-docker.sh \
        ./scripts/build-bootstraps.sh \
        --architectures "$TERMUX_ARCH" \
        --add "$PIPEROS_BOOTSTRAP_ADDITIONAL_PACKAGES"
)

source_archive="$UPSTREAM_DIR/bootstrap-$TERMUX_ARCH.zip"
target_archive="$DIST_DIR/piperos-bootstrap-$ANDROID_ABI-$PIPEROS_RUNTIME_VERSION.zip"

[[ -s "$source_archive" ]] ||
    { echo "Bootstrap archive was not created: $source_archive" >&2; exit 1; }
cp "$source_archive" "$target_archive"

sha256sum "$target_archive" >"$target_archive.sha256"
echo "Created $target_archive"
