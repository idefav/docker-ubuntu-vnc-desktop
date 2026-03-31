# Architecture

## Components

- Ubuntu 24.04 base system
- `tini` + `supervisord`
- `nginx`
- Python backend on port `6079`
- Vue frontend wrapping noVNC
- noVNC + websockify
- `Xvfb` on `DISPLAY=:1`
- `x11vnc` exposing the X server on port `5900`
- GNOME desktop session running on X11

## Runtime flow

- `startup.sh` prepares the desktop user, applies runtime config, and starts supervisor.
- Supervisor starts `Xvfb`, GNOME session, `x11vnc`, noVNC, nginx, and the Python backend.
- The frontend polls `/api/state` and requests `/api/reset` when the browser viewport changes.
- The backend stores the target resolution in a runtime file consumed by `xvfb.sh`.

## Resize strategy

- If `RESOLUTION` is set, the virtual desktop stays fixed.
- Otherwise the frontend first requests server-side resize.
- If the X server cannot resize quickly enough, the frontend switches the active noVNC session to local scaling.
