#!/bin/bash

RESOLUTION_FILE=${RESOLUTION_FILE:-/run/desktop-resolution}
DESKTOP_USERNAME=${DESKTOP_USERNAME:-${USER:-}}
DESKTOP_PASSWORD=${DESKTOP_PASSWORD:-${PASSWORD:-}}

if [ -n "$VNC_PASSWORD" ]; then
    if command -v tigervncpasswd >/dev/null 2>&1; then
        printf '%s\n' "$VNC_PASSWORD" | tigervncpasswd -f > /.password2
    else
        printf '%s\n' "$VNC_PASSWORD" | vncpasswd -f > /.password2
    fi
    chmod 400 /.password2
    export VNC_PASSWORD_FILE=/.password2
    export VNC_PASSWORD=
fi

if [ -n "$X11VNC_ARGS" ] && [ -z "$XVNC_ARGS" ]; then
    export XVNC_ARGS="$X11VNC_ARGS"
fi

if [ -n "$RESOLUTION" ]; then
    echo "$RESOLUTION" > "$RESOLUTION_FILE"
fi

if [ -z "$DESKTOP_USERNAME" ]; then
    DESKTOP_USERNAME=root
fi

USER=$DESKTOP_USERNAME
HOME=/root
if [ "$DESKTOP_USERNAME" != "root" ]; then
    echo "* enable custom user: $DESKTOP_USERNAME"
    if ! id "$DESKTOP_USERNAME" >/dev/null 2>&1; then
        useradd --create-home --shell /bin/bash --user-group --groups adm,sudo "$DESKTOP_USERNAME"
    fi
    if [ -z "$DESKTOP_PASSWORD" ]; then
        echo "  set default password to \"ubuntu\""
        DESKTOP_PASSWORD=ubuntu
    fi
    HOME=/home/$DESKTOP_USERNAME
    echo "$DESKTOP_USERNAME:$DESKTOP_PASSWORD" | chpasswd
    for config_path in /root/.config /root/.gtkrc-2.0 /root/.asoundrc; do
        if [ -e "$config_path" ]; then
            cp -r "$config_path" "${HOME}"
        fi
    done
    chown -R "$DESKTOP_USERNAME:$DESKTOP_USERNAME" "${HOME}"
    [ -d "/dev/snd" ] && chgrp -R adm /dev/snd
fi
sed -i -e "s|%USER%|$USER|" -e "s|%HOME%|$HOME|" /etc/supervisor/conf.d/supervisord.conf

if [ -n "$DESKTOP_INIT_SCRIPT" ] && [ -x "$DESKTOP_INIT_SCRIPT" ]; then
    "$DESKTOP_INIT_SCRIPT" "$USER" "$HOME"
fi

# nginx workers
sed -i 's|worker_processes .*|worker_processes 1;|' /etc/nginx/nginx.conf

# nginx ssl
if [ -n "$SSL_PORT" ] && [ -e "/etc/nginx/ssl/nginx.key" ]; then
    echo "* enable SSL"
	sed -i 's|#_SSL_PORT_#\(.*\)443\(.*\)|\1'$SSL_PORT'\2|' /etc/nginx/sites-enabled/default
	sed -i 's|#_SSL_PORT_#||' /etc/nginx/sites-enabled/default
fi

# nginx http base authentication
if [ -n "$HTTP_PASSWORD" ]; then
    echo "* enable HTTP base authentication"
    htpasswd -bc /etc/nginx/.htpasswd $USER $HTTP_PASSWORD
	sed -i 's|#_HTTP_PASSWORD_#||' /etc/nginx/sites-enabled/default
fi

# dynamic prefix path renaming
if [ -n "$RELATIVE_URL_ROOT" ]; then
    echo "* enable RELATIVE_URL_ROOT: $RELATIVE_URL_ROOT"
	sed -i 's|#_RELATIVE_URL_ROOT_||' /etc/nginx/sites-enabled/default
	sed -i 's|_RELATIVE_URL_ROOT_|'$RELATIVE_URL_ROOT'|' /etc/nginx/sites-enabled/default
fi

# clearup
DESKTOP_PASSWORD=
HTTP_PASSWORD=

exec /bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf
