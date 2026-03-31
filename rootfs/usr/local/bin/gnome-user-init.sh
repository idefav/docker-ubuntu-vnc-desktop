#!/bin/bash

set -e

TARGET_USER="$1"
TARGET_HOME="$2"
DESKTOP_DIR="${TARGET_HOME}/Desktop"

mkdir -p "$DESKTOP_DIR"
rm -f "$DESKTOP_DIR"/*.desktop 2>/dev/null || true
chown -R "$TARGET_USER:$TARGET_USER" "$DESKTOP_DIR"
