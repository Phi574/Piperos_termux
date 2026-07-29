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
    memory_available="$(free -h 2>/dev/null | awk '/^Mem:/ { print $7 }')"
    disk_available="$(df -h "$(dirname "$LOG_FILE")" 2>/dev/null | awk 'NR == 2 { print $4 }')"
    printf '[PiperOS heartbeat] elapsed=%02d:%02d:%02d log=%s\n' \
        "$((elapsed / 3600))" "$(((elapsed % 3600) / 60))" \
        "$((elapsed % 60))" "$log_size"
    printf '  resources: memory_available=%s disk_available=%s\n' \
        "${memory_available:-unknown}" "${disk_available:-unknown}"
    [[ -z "$latest" ]] || printf '  latest: %s\n' "$latest"
done

set +e
wait "$command_pid"
status=$?
set -e

if ((status != 0)); then
    failure="$(
        grep -E \
            '(fatal error:|clang.*error:|ninja: build stopped|Killed|Cannot allocate memory|No space left|ERROR:|Failed to build|exited with exit code)' \
            "$LOG_FILE" |
            tail -n 1 || true
    )"
    if [[ -n "$failure" ]]; then
        sanitized_failure="${failure//'%'/'%25'}"
        sanitized_failure="${sanitized_failure//$'\r'/'%0D'}"
        sanitized_failure="${sanitized_failure//$'\n'/'%0A'}"
        printf '::error title=PiperOS bootstrap failed::%s\n' "$sanitized_failure"
    fi
    echo "Command failed with exit code $status. Final log lines:"
    tail -n 200 "$LOG_FILE"

    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        {
            echo "## Bootstrap failure"
            echo
            echo "\`$failure\`"
            echo
            echo "The complete log is available in the architecture log artifact."
        } >>"$GITHUB_STEP_SUMMARY"
    fi
    exit "$status"
fi

elapsed=$((SECONDS - start_time))
printf '[PiperOS complete] elapsed=%02d:%02d:%02d log=%s\n' \
    "$((elapsed / 3600))" "$(((elapsed % 3600) / 60))" \
    "$((elapsed % 60))" "$(du -h "$LOG_FILE" | cut -f1)"
