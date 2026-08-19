# kvmd-restart

Floating restart-PiKVM-OS button for the PiKVM Web UI.

Adds a button to the KVM stream view that reboots the PiKVM itself — not the
attached host — behind a confirmation dialog, so a misclick can't drop the box
you are using to reach everything else.

## Features

- Floating restart button in the Web UI, with a confirm step
- Reboot runs through kvmd's own GPIO `cmd` driver, so no extra service is needed
- Scoped sudo rule: `kvmd` may run `systemctl reboot` and nothing else
- Auto-reapplies after kvmd updates via pacman hook

## Install

```bash
makepkg -si
# Or install pre-built package:
pacman -U kvmd-restart-1.0.0-1-any.pkg.tar.zst
```

## How it works

**Config:** Registers a `cmd`-type GPIO driver in `/etc/kvmd/override.d/` that
shells out to `sudo systemctl reboot`.

**Privilege:** `/etc/sudoers.d/` grants the `kvmd` user NOPASSWD on exactly
`/usr/bin/systemctl reboot` — one command, no wildcard.

**Client-side:** `apply-patches.sh` injects the button and its stylesheet into
the Web UI, and the pacman hook re-runs it after a kvmd upgrade overwrites the
shipped files.

## Note

The reboot is immediate once confirmed. Any in-progress mass-storage or HID
session drops with it.
