#!/bin/sh

set -eu

RESOLUTION_FILE="${RESOLUTION_FILE:-/run/desktop-resolution}"
RESOLUTION="${RESOLUTION:-1024x768}"
DEPTH="${VNC_DEPTH:-24}"

if [ -f "$RESOLUTION_FILE" ]; then
    FILE_RESOLUTION="$(cat "$RESOLUTION_FILE")"
    case "$FILE_RESOLUTION" in
        [0-9]*x[0-9]*)
            RESOLUTION="$FILE_RESOLUTION"
            ;;
    esac
fi

if command -v Xtigervnc >/dev/null 2>&1; then
    XVNC_BIN="$(command -v Xtigervnc)"
elif command -v Xvnc >/dev/null 2>&1; then
    XVNC_BIN="$(command -v Xvnc)"
else
    echo "Xvnc binary not found" >&2
    exit 1
fi

SECURITY_ARGS="-SecurityTypes None"
if [ -n "${VNC_PASSWORD_FILE:-}" ] && [ -f "${VNC_PASSWORD_FILE}" ]; then
    SECURITY_ARGS="-SecurityTypes VncAuth -PasswordFile ${VNC_PASSWORD_FILE}"
fi

exec "$XVNC_BIN" :1 \
    -geometry "$RESOLUTION" \
    -depth "$DEPTH" \
    -rfbport 5900 \
    -localhost no \
    -AlwaysShared \
    -AcceptCutText=1 \
    -AcceptSetDesktopSize=1 \
    -desktop "ubuntu-desktop-vnc" \
    -SendCutText=1 \
    -SendPrimary=1 \
    -SetPrimary=1 \
    $SECURITY_ARGS \
    ${XVNC_ARGS:-} \
    "$@"
