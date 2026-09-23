# AirPlay module

Makes the host show up in the iPhone's **AirPlay audio** picker, so phone audio
plays out of the desktop's speakers. Receive-only: nothing here sends audio *to*
the phone.

- **Server:** [UxPlay](https://github.com/FDH2/UxPlay) (GPLv3), an AirPlay 2
  receiver — mirroring with audio, plus an audio-only mode carrying Apple
  Lossless.
- **Advertised as:** the host's `networking.hostName` (`-nh` keeps UxPlay from
  appending `@hostname` to it).
- **Ports:** TCP+UDP 7100-7102, pinned with `-p 7100`, plus UDP 5353 for mDNS.

## Why xvimagesink and software decoding

Mirroring opens a window that stays black unless both `-avdec` and
`-vs xvimagesink` are set. What was tried, and why each failed:

| Attempt | Result |
|---|---|
| `decodebin` (picks `nvh264dec`) | outputs `CUDAMemory`; `videoconvert` cannot transform it, caps negotiation fails, no frame reaches the sink |
| `glimagesink` (upstream's NVIDIA advice, with `-vd nvh264dec`) | renders solid black, verified with a test pattern |
| `waylandsink` + I420/NV12 | no window at all; only `BGRx` negotiates |
| `waylandsink` + uxplay's I420 frames | window opens, thousands of `show_frame` calls, every buffer released — surface still black (`grim` confirms it is not a capture artifact). Also segfaulted once in `output_done`, a [known upstream crash](https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/-/issues/1306) |
| `-avdec` + `xvimagesink` (via XWayland) | works |

Software decoding costs little here and `xvimagesink` takes uxplay's I420
directly. Probably all downstream of sway running `--unsupported-gpu` on NVIDIA.

To test a sink without a phone, dump a session's h264 with `-vdmp`, then replay
it into the candidate and screenshot the window with `grim`.

## Mirroring vs AirPlay audio

The iPhone has two different AirPlay modes, and picking the wrong one looks like
a bug. With a video app in the foreground, "Screen Mirroring" often opens an
**audio-only** session: audio comes out the desktop, video stays on the phone,
and the two drift apart because remote audio is buffered ~2s with no attempt to
sync the phone's picture to it. The log tells you which you got:

```
ct=2 spf=352 usingScreen=0 isMedia=1   <- audio only, no video will ever arrive
ct=8 spf=480 usingScreen=1 isMedia=1   <- real mirroring
```

For real mirroring, start it from the Home screen or a non-video app.

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
