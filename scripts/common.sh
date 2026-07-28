#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PIPEROS_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PIPEROS_REPO_ROOT

# shellcheck source=../config/runtime.env
# shellcheck disable=SC1091
source "$PIPEROS_REPO_ROOT/config/runtime.env"

export PIPEROS_DATA_DIR="/data/data/$PIPEROS_APP_PACKAGE_NAME"
export PIPEROS_ROOTFS="$PIPEROS_DATA_DIR/files"
export PIPEROS_HOME="$PIPEROS_ROOTFS/home"
export PIPEROS_PREFIX="$PIPEROS_ROOTFS/usr"
readonly PIPEROS_DATA_DIR PIPEROS_ROOTFS PIPEROS_HOME PIPEROS_PREFIX

termux_arch_for_android_abi() {
    case "${1:-}" in
        arm64-v8a) echo "aarch64" ;;
        armeabi-v7a) echo "arm" ;;
        x86_64) echo "x86_64" ;;
        *)
            echo "Unsupported Android ABI: ${1:-<empty>}" >&2
            return 64
            ;;
    esac
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Required command not found: $1" >&2
        return 69
    fi
}

find_python() {
    if command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
        echo "python3"
    elif command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
        echo "python"
    else
        echo "Python 3 is required" >&2
        return 69
    fi
}
