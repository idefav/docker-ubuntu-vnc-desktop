#!/bin/sh

set -eu

mkdir -p /run/systemd /run/dbus /var/run/dbus
[ -e /etc/machine-id ] || dbus-uuidgen --ensure=/etc/machine-id
[ -e /var/lib/dbus/machine-id ] || ln -sf /etc/machine-id /var/lib/dbus/machine-id
[ -e /var/run/utmp ] || : > /var/run/utmp

for _ in $(seq 1 30); do
    if [ -S /run/dbus/system_bus_socket ]; then
        break
    fi
    sleep 1
done

export DBUS_SYSTEM_BUS_ADDRESS="${DBUS_SYSTEM_BUS_ADDRESS:-unix:path=/run/dbus/system_bus_socket}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}"

exec /lib/systemd/systemd-logind
