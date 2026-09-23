# KDE Connect module

Clipboard sync with the iPhone (`The Guide`), plus the ping/share/find-my-phone
plugins that come along with it. Files go over Taildrop instead — see
[`modules/tailscale/README.md`](../tailscale/README.md).

- [`default.nix`](./default.nix) — package + firewall (TCP/UDP 1714-1764).
- [`hm.nix`](./hm.nix) — `kdeconnectd` as a user service.

Clipboard sync works on sway because the plugin goes through `KSystemClipboard`,
which wants `ext_data_control_manager_v1` or `zwlr_data_control_manager_v1`.
wlroots implements both; GNOME's Wayland session implements neither, which is why
clipboard sync is reported broken there and works here.

## Clipboard auto-share must stay off

`kdeconnect.clipboardAutoShareDisabled` in [`hm.nix`](./hm.nix) lists the paired
device IDs that get:

```ini
# ~/.config/kdeconnect/<device-id>/kdeconnect_clipboard/config
[General]
autoShare=false
```

Leave it at the plugin's default (`true`) and **phone → desktop cannot work**:

- the plugin calls `sendConnectPacket()` on *every* connection, pushing the
  desktop's clipboard to the phone;
- the iOS app drops the link whenever it is backgrounded, so going to another
  app to copy something and then reopening KDE Connect to push re-establishes
  the link — and the desktop's clipboard lands on the phone first, overwriting
  what was copied;
- "Send clipboard" then sends the desktop's own text back, which the desktop
  applies (a received `kdeconnect.clipboard` packet is applied unconditionally).

The protocol does guard `kdeconnect.clipboard.connect` packets with a timestamp,
but iOS cannot observe its own clipboard in the background, so its local
timestamp is stale and the guard does not fire. Symptom when this bites: pushes
from the phone appear to do nothing, and the phone's clipboard keeps turning
back into whatever the desktop last copied.

With auto-share off, desktop → phone becomes deliberate:

```bash
busctl --user call org.kde.kdeconnect \
  /modules/kdeconnect/devices/<device-id>/clipboard \
  org.kde.kdeconnect.device.clipboard sendClipboard
```

Two consequences of keeping this in the flake: the file is a read-only symlink,
so the matching toggle in `kdeconnect-settings` will not stick, and the path is
keyed by the paired device ID — **re-pairing a device regenerates its ID**, so
the list in `flake.nix` has to be updated to match (`kdeconnect-cli -l`).

On the phone, iOS asks for pasteboard access the first time the app pushes a
clipboard; either answer works, "Allow" just stops it asking again.

## Gotchas

- **The phone is only connected while the app is foregrounded.** Expect the
  link to flap; `kdeconnect-cli -l` showing `(paired)` without "reachable"
  is normal, not a fault.
- **The DBus object path only exists while the device is connected**, so any
  `busctl` call against the clipboard plugin fails with "No such object path"
  when the app is closed.
- **Discovery is LAN broadcast**, but an established link will happily ride the
  tailnet — the device has shown up on `192.168.1.176`, on IPv6, and on
  `100.64.0.5` in the same session.

## Diagnostics cheat sheet

```bash
kdeconnect-cli -l                                     # paired? reachable? which address?
busctl --user tree org.kde.kdeconnect | grep clipboard # is the plugin loaded for the device?
busctl --user get-property org.kde.kdeconnect \
  /modules/kdeconnect/devices/<id>/clipboard \
  org.kde.kdeconnect.device.clipboard isAutoShareDisabled   # true = configured correctly
wl-paste -l                                           # data-control works if this prints types
wl-paste --watch <script>                             # log every clipboard change, timestamped
systemctl --user set-environment QT_LOGGING_RULES='kdeconnect.*=true'
systemctl --user restart kdeconnect                   # ...then journalctl --user -u kdeconnect -f
```

Received clipboard packets are not logged even at debug level, so `wl-paste
--watch` writing to a file is the reliable way to tell whether a push landed.
