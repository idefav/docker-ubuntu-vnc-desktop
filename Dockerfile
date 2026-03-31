FROM ubuntu:24.04 AS system

ARG APT_MIRROR=http://mirrors.tuna.tsinghua.edu.cn/ubuntu
ARG APT_PORTS_MIRROR=http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG NO_PROXY
ARG NVM_VERSION=v0.39.7
ARG NODE_VERSION=v24
ARG NVM_NODEJS_ORG_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release
ARG NPM_REGISTRY=https://registry.npmmirror.com
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ARG PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn
ENV DEBIAN_FRONTEND=noninteractive \
    RESOLUTION_FILE=/run/desktop-resolution \
    DESKTOP_INIT_SCRIPT=/usr/local/bin/gnome-user-init.sh \
    XDG_CURRENT_DESKTOP=ubuntu:GNOME \
    XDG_SESSION_DESKTOP=ubuntu \
    XDG_SESSION_TYPE=x11 \
    GNOME_SHELL_SESSION_MODE=ubuntu \
    GDK_BACKEND=x11 \
    MOZ_ENABLE_WAYLAND=0 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    ALL_PROXY=${ALL_PROXY} \
    NO_PROXY=${NO_PROXY} \
    no_proxy=${NO_PROXY} \
    NVM_DIR=/usr/local/nvm \
    PATH=/usr/local/nvm/current/bin:${PATH} \
    NVM_NODEJS_ORG_MIRROR=${NVM_NODEJS_ORG_MIRROR} \
    NPM_CONFIG_REGISTRY=${NPM_REGISTRY} \
    PIP_INDEX_URL=${PIP_INDEX_URL} \
    PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST}

RUN set -eux; \
    if [ -n "${HTTP_PROXY}" ] || [ -n "${HTTPS_PROXY}" ]; then \
        printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "${HTTP_PROXY}" "${HTTPS_PROXY:-$HTTP_PROXY}" > /etc/apt/apt.conf.d/99proxy; \
    fi

RUN set -eux; \
    sed -i "s#http://archive.ubuntu.com/ubuntu/#${APT_MIRROR}/#g" /etc/apt/sources.list.d/ubuntu.sources; \
    sed -i "s#http://security.ubuntu.com/ubuntu/#${APT_MIRROR}/#g" /etc/apt/sources.list.d/ubuntu.sources; \
    sed -i "s#http://ports.ubuntu.com/ubuntu-ports/#${APT_PORTS_MIRROR}/#g" /etc/apt/sources.list.d/ubuntu.sources; \
    sed -i 's/^Components: .*/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources

RUN set -eux; \
    apt-get update; \
    echo ">>> apt-get update completed"; \
    install_pkg() { \
        pkg="$1"; \
        echo ">>> installing package: $pkg"; \
        apt-get install -y --no-install-recommends "$pkg"; \
        echo ">>> package installed: $pkg"; \
    }; \
    base_packages=' \
        software-properties-common curl ca-certificates gnupg gpg-agent jq \
        apache2-utils supervisor nginx sudo net-tools zenity xz-utils \
        dbus-x11 dbus-user-session dbus x11-utils alsa-utils mesa-utils \
        libgl1-mesa-dri gdk-pixbuf2.0-bin librsvg2-common \
        tigervnc-standalone-server tigervnc-tools novnc websockify \
        fonts-ubuntu-classic fonts-wqy-zenhei python3-pip python3-dev \
        python3-venv build-essential pkg-config cmake gdb \
        xdg-user-dirs desktop-file-utils'; \
    desktop_packages=' \
        ubuntu-session gnome-shell gnome-terminal nautilus \
        gnome-control-center gnome-shell-ubuntu-extensions'; \
    dev_packages=' \
        git vim nano less tree file ripgrep fd-find tmux bash-completion \
        man-db wget zip unzip rsync openssh-client iputils-ping iproute2 \
        dnsutils traceroute inetutils-telnet netcat-openbsd lsof procps \
        psmisc htop strace'; \
    for pkg in $base_packages $desktop_packages $dev_packages; do \
        install_pkg "$pkg"; \
    done; \
    rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    if [ "$arch" = "amd64" ]; then \
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg; \
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list; \
        apt-get update; \
        echo ">>> apt-get update completed"; \
        apt-get install -y --no-install-recommends google-chrome-stable code; \
    elif [ "$arch" = "arm64" ]; then \
        add-apt-repository -y ppa:xtradeb/apps; \
        apt-get update; \
        echo ">>> apt-get update completed"; \
        apt-get install -y --no-install-recommends chromium code; \
    else \
        echo "Unsupported architecture for GNOME image: $arch" >&2; \
        exit 1; \
    fi; \
    rm -rf /var/lib/apt/lists/*

ARG TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64 /tmp/tini-amd64
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-arm64 /tmp/tini-arm64
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    if [ "$arch" = "amd64" ]; then \
        mv /tmp/tini-amd64 /bin/tini; \
    else \
        mv /tmp/tini-arm64 /bin/tini; \
    fi; \
    chmod +x /bin/tini; \
    rm -f /tmp/tini-amd64 /tmp/tini-arm64; \
    true

COPY rootfs/usr/local/lib/web/backend/requirements.txt /tmp/requirements.txt
RUN python3 -m pip config set global.index-url "$PIP_INDEX_URL" \
    && python3 -m pip config set global.trusted-host "$PIP_TRUSTED_HOST" \
    && python3 -m pip install --break-system-packages --ignore-installed --no-cache-dir setuptools wheel \
    && python3 -m pip install --break-system-packages --ignore-installed --no-cache-dir -r /tmp/requirements.txt \
    && ln -sf /usr/bin/python3 /usr/local/bin/python \
    && rm -f /tmp/requirements.txt

FROM ubuntu:24.04 AS builder

ARG APT_MIRROR=http://mirrors.tuna.tsinghua.edu.cn/ubuntu
ARG APT_PORTS_MIRROR=http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG NO_PROXY
ARG NVM_VERSION=v0.39.7
ARG NODE_VERSION=v24
ARG NVM_NODEJS_ORG_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release
ARG NPM_REGISTRY=https://registry.npmmirror.com

ENV DEBIAN_FRONTEND=noninteractive \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    ALL_PROXY=${ALL_PROXY} \
    NO_PROXY=${NO_PROXY} \
    no_proxy=${NO_PROXY} \
    NVM_DIR=/usr/local/nvm \
    PATH=/usr/local/nvm/current/bin:${PATH} \
    NVM_NODEJS_ORG_MIRROR=${NVM_NODEJS_ORG_MIRROR} \
    NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

RUN set -eux; \
    if [ -n "${HTTP_PROXY}" ] || [ -n "${HTTPS_PROXY}" ]; then \
        printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "${HTTP_PROXY}" "${HTTPS_PROXY:-$HTTP_PROXY}" > /etc/apt/apt.conf.d/99proxy; \
    fi

RUN set -eux; \
    sed -i "s#http://archive.ubuntu.com/ubuntu/#${APT_MIRROR}/#g" /etc/apt/sources.list.d/ubuntu.sources; \
    sed -i "s#http://security.ubuntu.com/ubuntu/#${APT_MIRROR}/#g" /etc/apt/sources.list.d/ubuntu.sources; \
    sed -i "s#http://ports.ubuntu.com/ubuntu-ports/#${APT_PORTS_MIRROR}/#g" /etc/apt/sources.list.d/ubuntu.sources; \
    sed -i 's/^Components: .*/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources

RUN apt-get update \
    && echo ">>> apt-get update completed" \
    && apt-get install -y --no-install-recommends curl ca-certificates git patch build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "$NVM_DIR" \
    && curl -fsSL "https://gitee.com/mirrors/nvm/raw/${NVM_VERSION}/install.sh" -o /tmp/install-nvm.sh \
    && PROFILE=/dev/null bash /tmp/install-nvm.sh \
    && . "$NVM_DIR/nvm.sh" \
    && RESOLVED_NODE_VERSION="$NODE_VERSION" \
    && if ! printf '%s' "$NODE_VERSION" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then \
        NODE_MAJOR="${NODE_VERSION#v}"; \
        RESOLVED_NODE_VERSION="$(nvm ls-remote | awk -v major="$NODE_MAJOR" '$1 ~ "^v" major "\\." { version=$1 } END { print version }')"; \
        test -n "$RESOLVED_NODE_VERSION"; \
      fi \
    && echo ">>> resolved Node.js version: $RESOLVED_NODE_VERSION" \
    && nvm install "$RESOLVED_NODE_VERSION" \
    && nvm alias default "$RESOLVED_NODE_VERSION" \
    && NODE_BIN_DIR="$(dirname "$(nvm which "$RESOLVED_NODE_VERSION")")" \
    && ln -sfn "$(dirname "$NODE_BIN_DIR")" "$NVM_DIR/current" \
    && npm config set registry "$NPM_REGISTRY" \
    && npm install -g yarn@1 pnpm \
    && yarn config set registry "$NPM_REGISTRY" \
    && ln -sf "$NVM_DIR/current/bin/node" /usr/local/bin/node \
    && ln -sf "$NVM_DIR/current/bin/npm" /usr/local/bin/npm \
    && ln -sf "$NVM_DIR/current/bin/npx" /usr/local/bin/npx \
    && ln -sf "$NVM_DIR/current/bin/corepack" /usr/local/bin/corepack \
    && ln -sf "$NVM_DIR/current/bin/yarn" /usr/local/bin/yarn \
    && ln -sf "$NVM_DIR/current/bin/pnpm" /usr/local/bin/pnpm \
    && rm -f /tmp/install-nvm.sh

COPY web /src/web
RUN cd /src/web \
    && sed -i 's#https://registry.yarnpkg.com/#https://registry.npmmirror.com/#g' yarn.lock \
    && yarn install --registry "$NPM_REGISTRY" \
    && yarn build \
    && if [ -f /src/web/dist/static/novnc/app/ui.js ]; then \
        sed -i 's#app/locale/#novnc/app/locale/#' /src/web/dist/static/novnc/app/ui.js; \
    fi

FROM system
LABEL maintainer="fcwu.tw@gmail.com"

COPY --from=builder /src/web/dist/ /usr/local/lib/web/frontend/
COPY --from=builder /usr/local/nvm/ /usr/local/nvm/
COPY rootfs /
RUN chmod +x /startup.sh \
    /usr/local/bin/xvnc.sh \
    /usr/local/bin/gnome-session.sh \
    /usr/local/bin/gnome-apply-settings.sh \
    /usr/local/bin/gnome-user-init.sh \
    /usr/local/bin/browser-launch \
    /usr/local/bin/system-dbus.sh \
    /usr/local/bin/system-logind.sh \
    && if [ ! -L "$NVM_DIR/current" ]; then \
        NODE_DIR="$NVM_DIR/versions/node/$(ls -1 "$NVM_DIR/versions/node" | tail -n 1)"; \
        ln -sfn "$NODE_DIR" "$NVM_DIR/current"; \
      fi \
    && ln -sfn "$NVM_DIR/current/bin/node" /usr/local/bin/node \
    && ln -sfn "$NVM_DIR/current/bin/npm" /usr/local/bin/npm \
    && ln -sfn "$NVM_DIR/current/bin/npx" /usr/local/bin/npx \
    && ln -sfn "$NVM_DIR/current/bin/corepack" /usr/local/bin/corepack \
    && ln -sfn "$NVM_DIR/current/bin/yarn" /usr/local/bin/yarn \
    && ln -sfn "$NVM_DIR/current/bin/pnpm" /usr/local/bin/pnpm \
    && update-desktop-database /usr/local/share/applications || true \
    && if command -v gdk-pixbuf-query-loaders >/dev/null 2>&1; then \
        gdk-pixbuf-query-loaders --update-cache || true; \
      fi \
    && ln -sfn /usr/share/novnc /usr/local/lib/web/frontend/static/novnc

EXPOSE 80
WORKDIR /root
ENV HOME=/home/ubuntu \
    SHELL=/bin/bash
HEALTHCHECK --interval=30s --timeout=5s CMD curl --fail http://127.0.0.1:6079/api/health
ENTRYPOINT ["/startup.sh"]
