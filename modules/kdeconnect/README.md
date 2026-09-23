# KDE Connect module

Clipboard sync with the iPhone (`The Guide`), on `thenixbeast` and on the Deck
in sway mode. Files go over Taildrop instead — see
[`modules/tailscale/README.md`](../tailscale/README.md) — and a URL is just
text, so the clipboard carries those too.

Everything lives in [`hm.nix`](./hm.nix): the daemon as a user service, the
package it runs, and the policy below. There is no NixOS half and nothing to
configure per host.

Clipboard sync works on sway because the plugin goes through `KSystemClipboard`,
which wants `ext_data_control_manager_v1` or `zwlr_data_control_manager_v1`.
wlroots implements both; GNOME's Wayland session implements neither, which is
why clipboard sync is reported broken there and works here.

## The policy is in the package, not in config files

Pairing is all-or-nothing: accept a device and every plugin it advertises goes
live, including `mousepad` — a keyboard and mouse for this machine. KDE Connect
only offers per-device config for this, keyed by a paired device ID that
changes on re-pair, and that binds nothing for a device paired after the last
`nh os switch`.

So the package is overridden instead. Two changes, both global and both
outliving any pairing:

- **Seven plugins are deleted**: `mousepad` and `shareinputdevicesremote`
  (remote control), `runcommand` (remote execution), `share` (drops files here
  and opens URLs here), `presenter`, `findthisdevice`, `findmyphone`. What
  remains is `clipboard`, `ping` and `battery`. A missing plugin is never
  advertised as a capability, so no device can ask for it and no toggle in
  `kdeconnect-settings` brings it back.
- **Clipboard auto-share defaults to off**, by patching the default in
  `clipboardplugin.cpp`. Leaving it on breaks phone → desktop pushes outright:
  the desktop overwrites the phone's clipboard as the link re-establishes, so
  "Send clipboard" ships our own text back, which the desktop then applies (a
  received `kdeconnect.clipboard` packet is applied unconditionally). The
  protocol does guard connect packets with a timestamp, but iOS cannot observe
  its own clipboard in the background, so its timestamp is stale and the guard
  never fires.

The cost is a ~2 minute local build of kdeconnect-kde whenever nixpkgs bumps
it, since neither change can come from the binary cache.

With auto-share off, desktop → phone becomes deliberate:

```bash
busctl --user call org.kde.kdeconnect \
  /modules/kdeconnect/devices/<device-id>/clipboard \
  org.kde.kdeconnect.device.clipboard sendClipboard
```

## Reachable over the tailnet and the hotspot, nowhere else

Nothing here opens a firewall port. `modules/tailscale` already puts
`tailscale0` in `networking.firewall.trustedInterfaces` and `modules/hotspot`
does the same for its AP, so KDE Connect is reachable on exactly those two and
on no untrusted LAN — which matters on a Deck that travels.

The cost is discovery. A LAN broadcast does not cross the tailnet, so peers
there are named in `customDevices`, written at activation time with
`kwriteconfig6`:

```
customDevices=100.64.0.5
```

That file is kdeconnectd's own — it writes `name` and `keyAlgorithm` there — so
the activation sets the single key rather than symlinking the file read-only
underneath the daemon. kdeconnect parses these with `QHostAddress` and does no
DNS, so **MagicDNS names do not work here**; the list is IP literals. The list
is read at startup and on network change, so activation restarts the daemon.

A link is bidirectional once established, so only one side needs to initiate,
and the phone's Tailscale VPN has to be on. Over the hotspot none of this
applies: broadcast discovery works normally there.

Pairing itself still needs the two devices to find each other — do it at home,
over the hotspot, or with both on the tailnet and the peer listed above.

## Gotchas

- **The phone is only connected while the app is foregrounded.** Expect the
  link to flap; `kdeconnect-cli -l` showing `(paired)` without "reachable"
  is normal, not a fault.
- **The DBus object path only exists while the device is connected**, so any
  `busctl` call against the clipboard plugin fails with "No such object path"
  when the app is closed.
- **iOS asks for pasteboard access** the first time the app pushes a clipboard.
  Either answer works; "Allow" just stops it asking again.

## Diagnostics cheat sheet

```bash
kdeconnect-cli -l                                      # paired? reachable? which address?
busctl --user tree org.kde.kdeconnect | grep clipboard  # is the plugin loaded for the device?
busctl --user get-property org.kde.kdeconnect \
  /modules/kdeconnect/devices/<id>/clipboard \
  org.kde.kdeconnect.device.clipboard isAutoShareDisabled    # true = as intended
kreadconfig6 --file ~/.config/kdeconnect/config \
  --group General --key customDevices                  # tailnet peers the daemon knows
wl-paste -l                                            # data-control works if this prints types
wl-paste --watch <script>                              # log every clipboard change, timestamped
systemctl --user set-environment QT_LOGGING_RULES='kdeconnect.*=true'
systemctl --user restart kdeconnect                    # ...then journalctl --user -u kdeconnect -f
```
