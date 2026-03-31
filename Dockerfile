FROM ubuntu:24.04 AS system

ARG APT_MIRROR=http://mirrors.tuna.tsinghua.edu.cn/ubuntu
ARG APT_PORTS_MIRROR=http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG NO_PROXY
ARG NVM_VERSION=v0.39.7
ARG NODE_VERSION=20.19.0
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
    install_pkg software-properties-common; \
    install_pkg curl; \
    install_pkg ca-certificates; \
    install_pkg gnupg; \
    install_pkg gpg-agent; \
    install_pkg jq; \
    install_pkg apache2-utils; \
    install_pkg supervisor; \
    install_pkg nginx; \
    install_pkg sudo; \
    install_pkg net-tools; \
    install_pkg zenity; \
    install_pkg xz-utils; \
    install_pkg dbus-x11; \
    install_pkg dbus-user-session; \
    install_pkg dbus; \
    install_pkg x11-utils; \
    install_pkg alsa-utils; \
    install_pkg mesa-utils; \
    install_pkg libgl1-mesa-dri; \
    install_pkg gdk-pixbuf2.0-bin; \
    install_pkg librsvg2-common; \
    install_pkg tigervnc-standalone-server; \
    install_pkg tigervnc-tools; \
    install_pkg novnc; \
    install_pkg websockify; \
    install_pkg vim-tiny; \
    install_pkg fonts-ubuntu-classic; \
    install_pkg fonts-wqy-zenhei; \
    install_pkg python3-pip; \
    install_pkg python3-dev; \
    install_pkg build-essential; \
    install_pkg xdg-user-dirs; \
    install_pkg ubuntu-session; \
    install_pkg gnome-shell; \
    install_pkg gnome-terminal; \
    install_pkg nautilus; \
    install_pkg gnome-control-center; \
    install_pkg gnome-shell-ubuntu-extensions; \
    install_pkg desktop-file-utils; \
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
ARG NODE_VERSION=20.19.0
ARG NVM_NODEJS_ORG_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release
ARG NPM_REGISTRY=https://registry.npmmirror.com

ENV DEBIAN_FRONTEND=noninteractive \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    ALL_PROXY=${ALL_PROXY} \
    NO_PROXY=${NO_PROXY} \
    no_proxy=${NO_PROXY} \
    NVM_DIR=/usr/local/nvm \
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
    && nvm install "$NODE_VERSION" \
    && nvm alias default "$NODE_VERSION" \
    && npm config set registry "$NPM_REGISTRY" \
    && npm install -g yarn@1 \
    && yarn config set registry "$NPM_REGISTRY" \
    && NODE_BIN_DIR="$NVM_DIR/versions/node/$(ls -1 $NVM_DIR/versions/node | tail -n 1)/bin" \
    && ln -sf "$NODE_BIN_DIR/node" /usr/local/bin/node \
    && ln -sf "$NODE_BIN_DIR/npm" /usr/local/bin/npm \
    && ln -sf "$NODE_BIN_DIR/npx" /usr/local/bin/npx \
    && ln -sf "$NODE_BIN_DIR/yarn" /usr/local/bin/yarn \
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
COPY rootfs /
RUN chmod +x /startup.sh \
    /usr/local/bin/xvnc.sh \
    /usr/local/bin/gnome-session.sh \
    /usr/local/bin/gnome-apply-settings.sh \
    /usr/local/bin/gnome-user-init.sh \
    /usr/local/bin/browser-launch \
    /usr/local/bin/system-dbus.sh \
    /usr/local/bin/system-logind.sh \
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
