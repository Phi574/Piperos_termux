#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

LOG_FILE="${1:-}"
shift || true

[[ -n "$LOG_FILE" && $# -gt 0 ]] || {
    echo "Usage: run-with-progress.sh LOG_FILE COMMAND [ARGUMENT ...]" >&2
    exit 64
}

mkdir -p "$(dirname "$LOG_FILE")"
: >"$LOG_FILE"

start_time="$SECONDS"
"$@" >"$LOG_FILE" 2>&1 &
command_pid=$!
next_report=60

while kill -0 "$command_pid" 2>/dev/null; do
    sleep 5
    elapsed=$((SECONDS - start_time))
    ((elapsed >= next_report)) || continue
    next_report=$((next_report + 60))
    log_size="$(du -h "$LOG_FILE" | cut -f1)"
    latest="$(
        grep -E \
            '(\[PiperOS [0-9]+/[0-9]+\]|termux - build of|Building .+ exited|Downloading |Created |ERROR:|Failed to build)' \
            "$LOG_FILE" |
            tail -n 1 || true
    )"
    printf '[PiperOS heartbeat] elapsed=%02d:%02d:%02d log=%s\n' \
        "$((elapsed / 3600))" "$(((elapsed % 3600) / 60))" \
        "$((elapsed % 60))" "$log_size"
    [[ -z "$latest" ]] || printf '  latest: %s\n' "$latest"
done

set +e
wait "$command_pid"
status=$?
set -e

if ((status != 0)); then
    echo "Command failed with exit code $status. Final log lines:"
    tail -n 120 "$LOG_FILE"
    exit "$status"
fi

elapsed=$((SECONDS - start_time))
printf '[PiperOS complete] elapsed=%02d:%02d:%02d log=%s\n' \
    "$((elapsed / 3600))" "$(((elapsed % 3600) / 60))" \
    "$((elapsed % 60))" "$(du -h "$LOG_FILE" | cut -f1)"
