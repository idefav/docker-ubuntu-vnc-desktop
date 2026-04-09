# Architecture

## Components

- Ubuntu 24.04 base system
- `tini` + `supervisord`
- `nginx`
- Python backend on port `6079`
- Vue frontend wrapping noVNC
- noVNC + websockify
- TigerVNC `Xvnc` on `DISPLAY=:1` and port `5900`
- GNOME desktop session running on X11

## Runtime flow

- `startup.sh` prepares the desktop user, applies runtime config, and starts supervisor.
- Supervisor starts `Xvnc`, GNOME session, websockify, nginx, and the Python backend.
- The frontend polls `/api/state` and requests `/api/reset` when the browser viewport changes.
- The backend stores the target resolution in a runtime file consumed by `xvnc.sh`.

## Resize strategy

- If `RESOLUTION` is set, the virtual desktop stays fixed.
- Otherwise the frontend first requests server-side resize.
- If the X server cannot resize quickly enough, the frontend switches the active noVNC session to local scaling.

## Clipboard

- Browser clipboard integration is implemented in the custom `web/static/vnc.html` wrapper.
- The runtime sync target is plain text only.
- The browser side requires a secure context for reliable clipboard read/write permissions.

## Desktop IME

- The image preinstalls Fcitx5 plus Chinese addons.
- User initialization writes a managed Fcitx5 profile and GNOME autostart entry.
- The GNOME session exports Fcitx5 IM environment variables and starts Fcitx5 with Pinyin as the default input method.
