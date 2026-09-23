# AirPlay module

Makes the host show up in the iPhone's **AirPlay audio** picker, so phone audio
plays out of the desktop's speakers. Receive-only: nothing here sends audio *to*
the phone.

- **Server:** [UxPlay](https://github.com/FDH2/UxPlay) (GPLv3), an AirPlay 2
  receiver — mirroring plus an audio-only mode that carries Apple Lossless.
- **Advertised as:** the host's `networking.hostName` (`-nh` keeps UxPlay from
  appending `@hostname` to it).
- **Ports:** TCP+UDP 7100-7102, pinned with `-p 7100`, plus UDP 5353 for mDNS.

## Why UxPlay and not shairport-sync

`shairport-sync` is the better-known answer and is the wrong one here:

- its **classic AirPlay 1 mode is broken by iOS 18+**
  ([#1866](https://github.com/mikebrady/shairport-sync/issues/1866)), so a
  modern iPhone will list it and then fail to play;
- its AirPlay 2 mode needs a package override (`enableAirplay2 = true`) *and* a
  hand-rolled `nqptp` daemon on UDP 319/320;
- the nixpkgs module runs it as a **system** user, which cannot reach the
  per-session PipeWire socket this config uses (`modules/audio`). Making it work
  would mean a system-wide PipeWire or a TCP pulse socket.

UxPlay is one package from nixpkgs, needs no override, tracks Apple's protocol
changes closely (v1.73.7 is from 2026-09-04), and runs fine as a user service.

## Enabling mirroring

`-vs 0` in [`hm.nix`](./hm.nix) disables video, so mirroring requests are
downgraded to audio and no window ever appears. Swap it for `-vs waylandsink` to
accept screen mirroring into a sway window; everything else stays as-is.

## Gotchas

- **The user service is tied to `graphical-session.target`.** No session, no
  AirPlay target — which is the intent, since there is nothing to play into.
- **mDNS is the whole discovery mechanism.** If the phone can't see the host,
  check avahi before anything else: `avahi-browse -art | grep -i airplay`.
- **Ports must stay in sync.** The `-p 7100` in `hm.nix` and the 7100-7102 range
  in `default.nix` are two halves of one decision; changing one alone silently
  breaks discovery-to-playback.

## Diagnostics cheat sheet

```bash
systemctl --user status uxplay          # is the receiver up?
journalctl --user -u uxplay -f          # connection attempts from the phone
avahi-browse -art | grep -i airplay     # is it being advertised?
pwvucontrol                             # is audio actually arriving at a sink?
```
