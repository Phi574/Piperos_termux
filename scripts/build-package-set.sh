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
PACKAGE_SET="$PIPEROS_REPO_ROOT/config/package-set.txt"
TARGET_DIR="$PIPEROS_REPO_ROOT/dist/packages/$ANDROID_ABI"
PYTHON_BIN="$(find_python)"

require_command docker
"$SCRIPT_DIR/validate-config.sh"
"$SCRIPT_DIR/prepare-upstream.sh" "$UPSTREAM_DIR"
"$PYTHON_BIN" "$SCRIPT_DIR/validate-package-set.py" \
    "$PACKAGE_SET" \
    --upstream "$UPSTREAM_DIR"

"$PYTHON_BIN" "$SCRIPT_DIR/validate-package-set.py" \
    "$PACKAGE_SET" \
    --upstream "$UPSTREAM_DIR" \
    --print >"$UPSTREAM_DIR/PIPEROS_PACKAGE_SET"
cp "$SCRIPT_DIR/upstream-build-package-set.sh" \
    "$UPSTREAM_DIR/scripts/piperos-build-package-set.sh"
chmod 755 "$UPSTREAM_DIR/scripts/piperos-build-package-set.sh"

mkdir -p "$UPSTREAM_DIR/output" "$TARGET_DIR"
find "$TARGET_DIR" -maxdepth 1 -type f -name '*.deb' -delete

builder_path="$PATH"
if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    sed -i \
        "s/--security-opt apparmor=_custom-termux-package-builder-\$CONTAINER_NAME/--security-opt apparmor=unconfined/" \
        "$UPSTREAM_DIR/scripts/run-docker.sh"
    builder_path="/usr/local/bin:/usr/bin:/bin"
fi

(
    cd "$UPSTREAM_DIR"
    PATH="$builder_path" CI=true CONTAINER_NAME="piperos-packages-$TERMUX_ARCH" \
        ./scripts/run-docker.sh \
        ./scripts/piperos-build-package-set.sh \
        "$TERMUX_ARCH"
)

copied=0
while IFS= read -r -d '' package_file; do
    cp "$package_file" "$TARGET_DIR/"
    copied=$((copied + 1))
done < <(
    find "$UPSTREAM_DIR/output" -maxdepth 1 -type f \
        \( -name "*_${TERMUX_ARCH}.deb" -o -name '*_all.deb' \) \
        -print0
)

((copied > 0)) ||
    { echo "No packages were produced for $ANDROID_ABI" >&2; exit 1; }

(
    cd "$TARGET_DIR"
    sha256sum -- *.deb >SHA256SUMS
)

echo "Collected $copied packages in $TARGET_DIR"
