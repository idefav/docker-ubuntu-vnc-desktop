#!/bin/bash

set -e

export DISPLAY="${DISPLAY:-:1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-${USER}}"
BACKGROUND_FILE="${BACKGROUND_FILE:-/usr/local/share/backgrounds/aurora-modern.ppm}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

for _ in $(seq 1 30); do
    if gsettings writable org.gnome.shell favorite-apps >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

gsettings set org.gnome.shell favorite-apps "['files.desktop', 'terminal.desktop', 'browser.desktop', 'code.desktop', 'settings.desktop']" || true
gsettings set org.gnome.shell enabled-extensions "['ubuntu-dock@ubuntu.com', 'ding@rastersoft.com']" || true
gsettings set org.gnome.shell.extensions.ding show-home true || true
gsettings set org.gnome.shell.extensions.ding show-trash true || true
if [ -f "$BACKGROUND_FILE" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file://${BACKGROUND_FILE}" || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file://${BACKGROUND_FILE}" || true
    gsettings set org.gnome.desktop.background picture-options 'zoom' || true
fi
