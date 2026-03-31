#!/bin/sh

RESOLUTION_FILE="${RESOLUTION_FILE:-/run/desktop-resolution}"
RESOLUTION="${RESOLUTION:-1024x768}"

if [ -f "$RESOLUTION_FILE" ]; then
    FILE_RESOLUTION="$(cat "$RESOLUTION_FILE")"
    case "$FILE_RESOLUTION" in
        [0-9]*x[0-9]*)
            RESOLUTION="$FILE_RESOLUTION"
            ;;
    esac
fi

exec /usr/bin/Xvfb :1 -screen 0 "${RESOLUTION}x24"
