# docker-ubuntu-vnc-desktop

Ubuntu 24.04 GNOME desktop in Docker, exposed through noVNC and VNC.

Repository: `https://github.com/idefav/docker-ubuntu-vnc-desktop`

## Features

- Ubuntu 24.04
- GNOME on X11
- noVNC with server-side resize first, local scaling fallback
- Desktop and Dock favorites for Files, Terminal, Browser, VS Code, Settings
- Browser launcher prefers Chrome on `amd64`, Chromium on `arm64`
- Domestic-first build sources:
  - `apt`: Tsinghua Ubuntu mirror over `http`
  - `apt` on arm64: Tsinghua Ubuntu Ports mirror over `http`
  - `nvm` install script: Gitee mirror
  - Node binary mirror: Tsinghua
  - `npm`: `registry.npmmirror.com`
  - `pip`: Tsinghua PyPI mirror
- Docker build uses `--network=host`
- Supports host proxy passthrough for build

## Quick Start

Build:

```shell
make build
```

Run:

```shell
make run DESKTOP_USERNAME=ubuntu DESKTOP_PASSWORD=ubuntu
```

Browse:

```text
http://127.0.0.1:6080/
```

Default desktop credentials in the example above:

```text
username: ubuntu
password: ubuntu
```

## Build With Host Proxy

If the host is running an HTTP proxy, pass it through directly:

```shell
make build \
  HTTP_PROXY=http://127.0.0.1:7890 \
  HTTPS_PROXY=http://127.0.0.1:7890
```

The Makefile always builds with `docker build --network=host`, so host-local proxies are reachable from the build context.

## Runtime Options

- `DESKTOP_USERNAME`: desktop login user; defaults to `root` when omitted
- `DESKTOP_PASSWORD`: password for the configured desktop user; defaults to `ubuntu` when a non-root user is created without an explicit password
- `RESOLUTION`: fixed resolution such as `1920x1080`; when omitted the frontend tries remote resize first and falls back to local noVNC scaling
- `VNC_PASSWORD`: optional VNC password
- `HTTP_PASSWORD`: optional HTTP basic auth password
- `RELATIVE_URL_ROOT`: optional subpath deployment prefix

## VNC Viewer

Expose port `5900` if you want a native VNC client:

```shell
docker run --privileged --rm \
  -p 6080:80 -p 5900:5900 \
  -v /dev/shm:/dev/shm \
  -e DESKTOP_USERNAME=ubuntu \
  -e DESKTOP_PASSWORD=ubuntu \
  idefav/ubuntu-desktop-gnome-vnc:latest
```

## SSL

Generate a self-signed certificate:

```shell
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/nginx.key -out ssl/nginx.crt
```

Then mount it to `/etc/nginx/ssl` and set `SSL_PORT`.

## Development

See [DEVELOPMENT.md](./DEVELOPMENT.md).

## Release Automation

- Pull requests to `main` automatically run a Docker build validation workflow
- Pushes to `main` automatically maintain a Release PR via Release Please
- Version increments follow Conventional Commits so `feat:` bumps minor, `fix:` bumps patch, and `feat!:` or `BREAKING CHANGE:` bumps major
- When the Release PR is merged, GitHub creates a release tag in `v1.0.0` format
- The same release workflow then builds and pushes Docker images with the exact same tag
- Images are always published to `ghcr.io/idefav/docker-ubuntu-vnc-desktop`
- If `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are configured in repository secrets, the same image is also published to Docker Hub
- If `RELEASE_PLEASE_TOKEN` is configured, Release Please will use it instead of the default `GITHUB_TOKEN`

## License

This project is distributed under the terms in [LICENSE](./LICENSE).
