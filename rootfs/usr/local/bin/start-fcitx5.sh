#!/bin/bash

set -euo pipefail

DESKTOP_IME_ENABLED="${DESKTOP_IME_ENABLED:-true}"
DESKTOP_IME_PRESET="${DESKTOP_IME_PRESET:-fcitx5-sogou}"
FCITX5_DEFAULT_IM="${FCITX5_DEFAULT_IM:-pinyin}"
FCITX5_STARTUP_TIMEOUT_SECONDS="${FCITX5_STARTUP_TIMEOUT_SECONDS:-20}"
FCITX5_DEFAULT_IM_TRIES="${FCITX5_DEFAULT_IM_TRIES:-20}"

is_truthy() {
    case "${1:-}" in
        1|true|TRUE|True|yes|YES|Yes|on|ON|On)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

log() {
    printf '[desktop-ime] %s\n' "$*" >&2
}

wait_for_fcitx5() {
    local deadline=$((SECONDS + FCITX5_STARTUP_TIMEOUT_SECONDS))

    while (( SECONDS < deadline )); do
        if command -v fcitx5-remote >/dev/null 2>&1 && fcitx5-remote -n >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

switch_default_im() {
    local tries=0

    while (( tries < FCITX5_DEFAULT_IM_TRIES )); do
        if fcitx5-remote -o >/dev/null 2>&1 && fcitx5-remote -s "$FCITX5_DEFAULT_IM" >/dev/null 2>&1; then
            log "default input method switched to ${FCITX5_DEFAULT_IM}"
            return 0
        fi
        tries=$((tries + 1))
        sleep 1
    done
    return 1
}

if ! is_truthy "$DESKTOP_IME_ENABLED"; then
    exit 0
fi

case "$DESKTOP_IME_PRESET" in
    fcitx5-sogou)
        ;;
    *)
        log "unsupported preset: ${DESKTOP_IME_PRESET}"
        exit 0
        ;;
esac

fcitx5 -d --replace

if ! wait_for_fcitx5; then
    log "fcitx5 control interface was not ready within ${FCITX5_STARTUP_TIMEOUT_SECONDS}s"
    exit 0
fi

if ! switch_default_im; then
    log "failed to switch default input method to ${FCITX5_DEFAULT_IM}"
fi
