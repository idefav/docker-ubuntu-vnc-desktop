#!/bin/bash

set -euo pipefail

TARGET_USER="${1:-root}"
TARGET_HOME="${2:-/root}"
DESKTOP_IME_ENABLED="${DESKTOP_IME_ENABLED:-true}"
DESKTOP_IME_PRESET="${DESKTOP_IME_PRESET:-fcitx5-sogou}"
AUTOSTART_DIR="${TARGET_HOME}/.config/autostart"
AUTOSTART_FILE="${AUTOSTART_DIR}/docker-ubuntu-fcitx5.desktop"
FCITX5_CONFIG_DIR="${TARGET_HOME}/.config/fcitx5"
FCITX5_CONF_DIR="${FCITX5_CONFIG_DIR}/conf"
FCITX5_PROFILE_FILE="${FCITX5_CONFIG_DIR}/profile"
FCITX5_CLOUDPINYIN_FILE="${FCITX5_CONF_DIR}/cloudpinyin.conf"
FCITX5_HOTKEY_FILE="${FCITX5_CONF_DIR}/hotkey.conf"
FCITX5_ADDONS_FILE="${FCITX5_CONF_DIR}/addons.conf"
AUTOSTART_TEMPLATE="/usr/local/share/applications/docker-ubuntu-fcitx5.desktop"

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

ensure_owner() {
    if [ "$TARGET_USER" = "root" ]; then
        return
    fi
    chown -R "$TARGET_USER:$TARGET_USER" "$@"
}

cleanup_ime() {
    rm -f "$AUTOSTART_FILE"
    rm -rf "$FCITX5_CONFIG_DIR"
    if [ -d "$TARGET_HOME/.config" ]; then
        ensure_owner "$TARGET_HOME/.config"
    fi
}

require_packages() {
    local packages=(
        fcitx5
        fcitx5-chinese-addons
        fcitx5-module-cloudpinyin
        fcitx5-pinyin-gui
        fcitx5-config-qt
        im-config
        fcitx5-frontend-gtk3
        fcitx5-frontend-gtk4
        fcitx5-frontend-qt5
    )
    local missing=()
    local package_name

    for package_name in "${packages[@]}"; do
        if ! dpkg -s "$package_name" >/dev/null 2>&1; then
            missing+=("$package_name")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "[desktop-ime] missing required packages: ${missing[*]}" >&2
        exit 1
    fi
}

write_profile() {
    mkdir -p "$FCITX5_CONF_DIR"

    cat > "$FCITX5_PROFILE_FILE" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=pinyin
Layout=

[Groups/0/Items/1]
Name=keyboard-us
Layout=

[GroupOrder]
0=Default
EOF

    cat > "$FCITX5_CLOUDPINYIN_FILE" <<'EOF'
[General]
Backend=Baidu
MinimumPinyinLength=2
EOF

    cat > "$FCITX5_HOTKEY_FILE" <<'EOF'
[Hotkey]
EnumerateGroupForwardKeys=
EnumerateGroupBackwardKeys=
TriggerKeys=Control+space
AltTriggerKeys=
EnumerateWithTriggerKeys=True
EOF

    cat > "$FCITX5_ADDONS_FILE" <<'EOF'
[Addons]
CloudPinyin=True
Pinyin=True
EOF

    chmod 0644 "$FCITX5_PROFILE_FILE" "$FCITX5_CLOUDPINYIN_FILE" "$FCITX5_HOTKEY_FILE" "$FCITX5_ADDONS_FILE"
    ensure_owner "$FCITX5_CONFIG_DIR"
}

configure_im_framework() {
    if ! command -v im-config >/dev/null 2>&1; then
        return
    fi
    if [ "$TARGET_USER" = "root" ]; then
        im-config -n fcitx5 >/dev/null 2>&1 || true
        return
    fi
    su - "$TARGET_USER" -c "im-config -n fcitx5 >/dev/null 2>&1 || true"
}

install_autostart() {
    mkdir -p "$AUTOSTART_DIR"
    cp "$AUTOSTART_TEMPLATE" "$AUTOSTART_FILE"
    chmod 0644 "$AUTOSTART_FILE"
    ensure_owner "$AUTOSTART_DIR"
}

if ! is_truthy "$DESKTOP_IME_ENABLED"; then
    cleanup_ime
    exit 0
fi

case "$DESKTOP_IME_PRESET" in
    fcitx5-sogou)
        ;;
    *)
        echo "[desktop-ime] unsupported preset: $DESKTOP_IME_PRESET" >&2
        cleanup_ime
        exit 0
        ;;
esac

require_packages
write_profile
configure_im_framework
install_autostart
