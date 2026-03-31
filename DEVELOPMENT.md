# Get code

```
git clone https://github.com/idefav/docker-ubuntu-vnc-desktop.git
```

This fork does not require submodule initialization.

# Test local code

## Build and run the GNOME image

```
make build
make run
```

When you need a host-local proxy during image build:

```
make build HTTP_PROXY=http://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890
```

## Develop backend

```
make shell
supervisorctl -c /etc/supervisor/supervisord.conf stop web
cd /usr/local/lib/web/backend
./run.py --debug
```

The runtime desktop image now ships with common development tools such as `git`, `vim`, `ping`, `telnet`, `node`, `npm`, `yarn`, and `pnpm`, so basic setup can happen directly inside the container shell.

## Develop frontend

```
cd web
sed -i '' 's#https://registry.yarnpkg.com/#https://registry.npmmirror.com/#g' yarn.lock
yarn install --registry https://registry.npmmirror.com
BACKEND=http://127.0.0.1:6080 npm run dev
```
