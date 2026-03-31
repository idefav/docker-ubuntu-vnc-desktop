#!/bin/sh

mkdir -p /run/dbus /var/run/dbus
rm -f /run/dbus/pid /var/run/dbus/pid

exec dbus-daemon --system --nofork --nopidfile
