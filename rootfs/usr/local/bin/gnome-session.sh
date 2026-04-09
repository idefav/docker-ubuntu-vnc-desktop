#!/bin/bash

set -e

export DISPLAY="${DISPLAY:-:1}"
export HOME="${HOME:-/root}"
export USER="${USER:-root}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-ubuntu:GNOME}"
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-ubuntu}"
export GNOME_SHELL_SESSION_MODE="${GNOME_SHELL_SESSION_MODE:-ubuntu}"
export GDK_BACKEND="${GDK_BACKEND:-x11}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-${USER}}"
export DBUS_SYSTEM_BUS_ADDRESS="${DBUS_SYSTEM_BUS_ADDRESS:-unix:path=/run/dbus/system_bus_socket}"

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

if is_truthy "${DESKTOP_IME_ENABLED:-true}"; then
    export GTK_IM_MODULE="${GTK_IM_MODULE:-fcitx5}"
    export QT_IM_MODULE="${QT_IM_MODULE:-fcitx5}"
    export XMODIFIERS="${XMODIFIERS:-@im=fcitx5}"
    export SDL_IM_MODULE="${SDL_IM_MODULE:-fcitx5}"
    export INPUT_METHOD="${INPUT_METHOD:-fcitx5}"
    export XIM="${XIM:-fcitx5}"
fi

mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

for _ in $(seq 1 30); do
    if [ -S /run/dbus/system_bus_socket ]; then
        break
    fi
    sleep 1
done

for _ in $(seq 1 30); do
    if busctl --system --no-pager call \
        org.freedesktop.login1 \
        /org/freedesktop/login1 \
        org.freedesktop.DBus.Peer \
        Ping >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

exec dbus-run-session -- bash -lc '
    /usr/local/bin/gnome-apply-settings.sh &
    if command -v vncconfig >/dev/null 2>&1; then
        vncconfig -nowin >/tmp/vncconfig.log 2>&1 &
    fi
    exec gnome-session --session=ubuntu
'
