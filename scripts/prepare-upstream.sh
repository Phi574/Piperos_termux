#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

UPSTREAM_DIR="${1:-$PIPEROS_REPO_ROOT/.work/termux-packages}"

require_command git
PYTHON_BIN="$(find_python)"

if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
    mkdir -p "$(dirname "$UPSTREAM_DIR")"
    git clone --filter=blob:none "$TERMUX_PACKAGES_REPOSITORY" "$UPSTREAM_DIR"
fi

git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$TERMUX_PACKAGES_COMMIT"
git -C "$UPSTREAM_DIR" checkout --detach "$TERMUX_PACKAGES_COMMIT"
git -C "$UPSTREAM_DIR" reset --hard "$TERMUX_PACKAGES_COMMIT"
git -C "$UPSTREAM_DIR" clean -ffd

"$PYTHON_BIN" - "$UPSTREAM_DIR/scripts/properties.sh" "$PIPEROS_APP_PACKAGE_NAME" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
package_name = sys.argv[2]
source = path.read_text(encoding="utf-8")
needle = 'TERMUX_APP__PACKAGE_NAME="com.termux"'
replacement = f'TERMUX_APP__PACKAGE_NAME="{package_name}"'

if source.count(needle) != 1:
    raise SystemExit(
        "Upstream properties changed: expected exactly one default package declaration"
    )

path.write_text(source.replace(needle, replacement), encoding="utf-8")
PY

"$PYTHON_BIN" - "$UPSTREAM_DIR/packages/xorg-util-macros/build.sh" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
upstream = (
    "https://xorg.freedesktop.org/releases/individual/util/"
    "util-macros-${TERMUX_PKG_VERSION}.tar.xz"
)
mirror = (
    "https://mirror.metanet.ch/BLFS/12.3/Xorg/"
    "util-macros-${TERMUX_PKG_VERSION}.tar.xz"
)

if source.count(upstream) != 1:
    raise SystemExit(
        "Upstream xorg-util-macros source changed: expected exactly one URL"
    )

path.write_text(source.replace(upstream, mirror), encoding="utf-8")
PY

grep -Fqx "TERMUX_APP__PACKAGE_NAME=\"$PIPEROS_APP_PACKAGE_NAME\"" \
    "$UPSTREAM_DIR/scripts/properties.sh" ||
    { echo "Patched application id verification failed" >&2; exit 1; }
# shellcheck disable=SC2016
grep -Fqx 'TERMUX_APP__DATA_DIR="/data/data/$TERMUX_APP__PACKAGE_NAME"' \
    "$UPSTREAM_DIR/scripts/properties.sh" ||
    { echo "Upstream data directory contract changed" >&2; exit 1; }
grep -Fqx 'TERMUX__PREFIX_SUBDIR="usr"' "$UPSTREAM_DIR/scripts/properties.sh" ||
    { echo "Upstream prefix contract changed" >&2; exit 1; }
grep -Fq 'https://mirror.metanet.ch/BLFS/12.3/Xorg/' \
    "$UPSTREAM_DIR/packages/xorg-util-macros/build.sh" ||
    { echo "X.Org mirror patch verification failed" >&2; exit 1; }

cat >"$UPSTREAM_DIR/PIPEROS_BUILD_METADATA" <<EOF
PIPEROS_APP_PACKAGE_NAME=$PIPEROS_APP_PACKAGE_NAME
PIPEROS_RUNTIME_VERSION=$PIPEROS_RUNTIME_VERSION
PIPEROS_PREFIX=$PIPEROS_PREFIX
TERMUX_PACKAGES_COMMIT=$TERMUX_PACKAGES_COMMIT
EOF

echo "Prepared Termux packages at $UPSTREAM_DIR"
