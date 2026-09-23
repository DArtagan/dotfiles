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

## GStreamer plugins are wrapped in by hand

nixpkgs' `uxplay` lists the GStreamer plugin sets in `buildInputs` but installs
a **bare, unwrapped ELF** — no `GST_PLUGIN_SYSTEM_PATH_1_0`, so GStreamer finds
none of them. Straight from nixpkgs, `gst-inspect-1.0 waylandsink` and
`avdec_h264` both come up empty and the service aborts at startup with:

```
gst_parse_launch error (audio 1): no element "pipewiresink"
```

[`hm.nix`](./hm.nix) therefore re-wraps the binary with an explicit plugin path.
Two traps in doing so:

- `pipewiresink` is in the **pipewire** package, not in any `gst-plugins-*`.
- `gst_all_1.gstreamer`'s default output is `bin`, whose `lib/gstreamer-1.0` is
  empty; the core plugins (`queue`, `capsfilter`) are in `out`. Hence
  `lib.makeSearchPathOutput "out"` rather than `lib.makeSearchPath`.

Audio-only masked most of this for a while, because uxplay decodes ALAC itself
and needed nothing but a sink. Mirroring needs `h264parse`, `avdec_h264`,
`videoconvert` and `waylandsink` on top.

To check the wrapper after a change, pull the path back out of the built binary
and inspect against it:

```bash
bin=$(nix eval --raw .#nixosConfigurations.thenixbeast.config.home-manager.users.will.systemd.user.services.uxplay.Service.ExecStart \
  | grep -o '/nix/store/[^ ]*/bin/uxplay')
gst_path=$(grep -o '/nix/store/[^:"]*gstreamer-1\.0' "$bin" | sort -u | tr '\n' ':')
GST_PLUGIN_SYSTEM_PATH_1_0="$gst_path" gst-inspect-1.0 waylandsink
```

## Why xvimagesink and software decoding

Mirroring needs two non-obvious flags on this machine. Both were found by
capturing a real session (`-vdmp` dumps the received h264) and replaying it into
each candidate sink while screenshotting the result with `grim`.

**`-avdec` (software h264).** `decodebin` picks `nvh264dec`, which outputs
frames in `CUDAMemory`. `videoconvert` cannot transform that:

```
videoconvert0: transform could not transform video/x-raw(memory:CUDAMemory), format=NV12 ... in anything we support
decodebin0:src_0: could not send sticky events
```

Caps negotiation then fails and no frame ever reaches the sink. Upstream
suggests `-vd nvh264dec` with `glimagesink` for NVIDIA, but glimagesink renders
solid black here (verified with a test pattern), so software decoding it is —
1080p h264 is nothing for this CPU.

**`-vs xvimagesink` (not waylandsink).** waylandsink cannot take YUV on this
box: a pipeline with an `I420` or `NV12` caps filter into it produces no window
at all, while `BGRx` works. With uxplay's I420 frames it does open a window,
reports thousands of successful `show_frame` calls, and has each buffer
released by the compositor — yet the surface is black, and `grim` confirms the
black is real, not a capture artifact. The same frames replayed into
`xvimagesink` (through XWayland) display perfectly. This is very likely
downstream of sway running `--unsupported-gpu` on NVIDIA.

waylandsink also segfaulted once in `output_done` (a `wl_output` event handler),
a [known upstream crash family](https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/-/issues/1306).

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

## Audio-only mode

Set `-vs 0` to refuse video entirely and downgrade mirroring requests to audio.

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
