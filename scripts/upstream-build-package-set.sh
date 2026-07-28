#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

TERMUX_ARCH="${1:-}"
PACKAGE_SET="${2:-PIPEROS_PACKAGE_SET}"

[[ "$TERMUX_ARCH" =~ ^(aarch64|arm|x86_64)$ ]] ||
    { echo "Unsupported Termux architecture: ${TERMUX_ARCH:-<empty>}" >&2; exit 64; }
[[ -s "$PACKAGE_SET" ]] ||
    { echo "Package set not found or empty: $PACKAGE_SET" >&2; exit 66; }

package_count="$(grep -cve '^[[:space:]]*$' "$PACKAGE_SET")"
package_index=0

while IFS= read -r package_name; do
    [[ -n "$package_name" ]] || continue
    package_index=$((package_index + 1))
    printf '\n[PiperOS %s/%s] Building %s for %s\n' \
        "$package_index" "$package_count" "$package_name" "$TERMUX_ARCH"
    ./build-package.sh -a "$TERMUX_ARCH" "$package_name"
done <"$PACKAGE_SET"

echo "PiperOS package set completed for $TERMUX_ARCH."
