# x-ui Custom Colors Installer

An installer script to add **Custom Colors** controls to **x-ui / 3x-ui** panel UI.

Maintained by **@Schmi7zz** on Telegram.  
Telegram channel: **@Schmitzws**

## What it does

- Rebuilds `x-ui` from source and patches the embedded panel templates to add:
  - Custom colors modal
  - Hover background control
  - Table header background control
  - Protect protocol tags (e.g. `tcp/ws/grpc/TLS/Reality`) from being recolored
  - Theme controls visible in both desktop sidebar and mobile drawer
- Creates a backup of the current binary at:
  - `/usr/local/x-ui/x-ui.bak.YYYYMMDD-HHMMSS`

## Requirements

- Ubuntu/Debian VPS
- `x-ui` installed as `systemd` service `x-ui`
- Root access (`sudo`)

## Install (one command)

After you host this repo on GitHub, users can run:

```bash
curl -fsSL "https://raw.githubusercontent.com/<YOU>/<REPO>/main/xui-colors.sh" | sudo bash -s -- install --yes
```

## What to click in the panel

- Open the panel
- Sidebar → **Theme** → **Custom colors**
- Enable custom colors and choose your colors

## Uninstall / rollback

This repo provides an automated uninstall (rollback to the exact backup created during install):

```bash
curl -fsSL "https://raw.githubusercontent.com/<YOU>/<REPO>/main/xui-colors.sh" | sudo bash -s -- uninstall --yes
```

Manual rollback (if needed):

1) Stop service:

```bash
sudo systemctl stop x-ui
```

2) Restore the latest backup:

```bash
ls -1t /usr/local/x-ui/x-ui.bak.* | head
sudo cp -a /usr/local/x-ui/x-ui.bak.YYYYMMDD-HHMMSS /usr/local/x-ui/x-ui
sudo chmod 755 /usr/local/x-ui/x-ui
sudo systemctl start x-ui
```

## Credits

- 3x-ui upstream: `https://github.com/MHSanaei/3x-ui`

