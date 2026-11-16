# DroidCam module

An iPhone as webcam and mic, through OBS, for video calls in Firefox. Set up and
tested on the Steam Deck (Wi-Fi, OBS 32.2, droidcam-obs 2.5.1).

What [`default.nix`](./default.nix) provides:

- **OBS** with the `droidcam-obs` plugin.
- **"OBS Cam"**, OBS's virtual camera (v4l2loopback, `/dev/video1`).
- **"OBS Mic"**, a virtual mic. OBS's virtual camera is video-only, so the phone's
  audio reaches apps by OBS *monitoring* it into the "OBS Mic Feed" sink, which a
  PipeWire loopback exposes as the "OBS Mic" source.

Everything below is OBS state that OBS writes itself, so it's set by hand in OBS,
not declared here.

## After a rebuild that changes the virtual mic

PipeWire only reads its config at start, and OBS loses its audio devices when
PipeWire restarts. Restart both, in this order:

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

Then quit and reopen OBS. Until OBS restarts, "OBS Mic Feed" isn't offered as a
monitoring device.

## The phone

- **Rear camera.** On an old iPhone it's far better than the front one.
- **Do Not Disturb** on. A phone call would take over the camera and mic.
- **On a charger**, out of its case if it runs hot. Lock focus and exposure in the
  app so they don't hunt.
- On **Wi-Fi**, the phone and the Deck must be on the same network, preferably
  5 GHz. The plugin finds the phone over mDNS (UDP 5353, open via avahi). Guest,
  hotel and coworking Wi-Fi often isolate clients; there, put the phone on the
  Deck's hotspot (`modules/hotspot`), or type the phone's IP into the source's
  "Use WiFi IP".

## OBS settings

**Settings → Video:** Base and Output both **1280×720**, **30 fps**. Meeting apps
send 720p at most.

**Settings → Audio:** Sample Rate **48 kHz**. Desktop Audio and Mic/Aux
**Disabled**. Advanced → Monitoring Device: **OBS Mic Feed**.

**DroidCam source properties:**

- Resolution: see [Framing](#framing).
- Video Format **AVC**, with AVC/HEVC hardware acceleration allowed.
- **Enable Audio** and **Sync Audio/Video** on.
- **Ultra-low latency** off. Buffered output copes better with Wi-Fi hiccups.

## Framing

The canvas is 16:9 landscape. With the phone upright, the plugin delivers the
image **sideways**, and the picture can be no wider than the camera's narrow side.
So turning the phone landscape is the setup in use. The portrait recipes are for
when the mount can't hold the phone sideways.

### Landscape phone (in use)

1. Resolution **1920×1080**.
2. Right-click the source → **Transform → Reset Transform**, then **Transform →
   Fit to screen** (Ctrl+F). It fills the canvas with no bars.
3. If the image is upside down, turn the phone the other way, or use **Transform
   → Rotate 180°**.

Widen the shot by moving the phone back. Zooming out isn't possible in OBS.

### Portrait phone

Not tested end to end; landscape replaced it. A 16:9 slice is cut from the
sideways image with a filter, then rotated upright in Edit Transform.

**Don't use "Fit to screen" here.** It resets the rotation to 0.

The narrow side of the phone's image becomes the width of the shot, so this is a
tighter, head-and-shoulders view at best. A 4:3 resolution shows more of the
sensor's narrow side than 16:9: about a third more width, and sharper.

**1. Resolution and Crop/Pad filter.** Right-click the source → **Filters**. Under
**Effect Filters**, add **Crop/Pad**, untick **Relative**, and use the row for the
resolution:

| Resolution | Aspect | Y | Width | Height | X (framing) |
|---|---|---|---|---|---|
| 1920×1080 | 16:9 | 0 | 608 | 1080 | 0–1312, start at 400 |
| 1920×1440 | 4:3 | 0 | 810 | 1440 | 0–1110, start at 400 |

1920×1440 only shows in the list once the app unlocks extra resolutions.

**2. Edit Transform.** Right-click the source → **Transform → Reset Transform**,
then **Transform → Edit Transform…**:

| Field | Value |
|---|---|
| Bounds Type | **Automatic** |
| Rotation | **90**, or **270** if upside down |
| Size | Width **720**, Height **1280** |
| Alignment | **Center** |
| Position | X **640**, Y **360** |

Size is measured before rotation, so it's entered tall; after the turn it fills
the canvas. Center alignment makes the image turn around its middle, and 640, 360
is the middle of the canvas. These values are the same for both resolutions,
because both crops are 9:16.

**3. Framing.** In the Crop/Pad filter, **X** moves the shot up and down your
body; which way depends on the rotation, so nudge it in steps of 50–100. Aim for
your eyes a third of the way down. To zoom in, use a smaller 9:16 slice and keep
it centred with Y = (full Height − Height) ÷ 2. For example, at 1920×1080: Width
540, Height 960, Y 60.

## Audio

On the DroidCam source:

1. **Advanced Audio Properties:** tick **Mono**. Audio Monitoring: **Monitor Only
   (mute output)**.
2. **Filters → Audio Filters**, in this order:
   1. **Noise Suppression**, method **RNNoise**
   2. **Compressor**: Ratio 3:1, Threshold −20 dB, Attack 5 ms, Release 80 ms
   3. **Limiter**: Threshold −3 dB
3. At interview volume, the source's meter in the Audio Mixer should peak in the
   yellow. If it stays green, raise the Compressor's Output Gain a few dB.

Use **headphones**, so the other side's voice doesn't echo back into the phone.

## Testing

Start OBS's **Virtual Camera** first, then record 10 s of exactly what Firefox
will get, clapping on camera:

```bash
nix shell nixpkgs#ffmpeg nixpkgs#mpv -c sh -c \
  'ffmpeg -f v4l2 -framerate 30 -video_size 1280x720 -i /dev/video1 -f pulse -i obs_mic -t 10 -y /tmp/clap.mkv && mpv /tmp/clap.mkv'
```

- **Clap out of step with the hands:** adjust the source's **Sync Offset** in
  Advanced Audio Properties.
- **Nothing heard:** check whether the recording itself is silent:

  ```bash
  nix shell nixpkgs#ffmpeg -c ffmpeg -hide_banner -i /tmp/clap.mkv -map 0:a -af volumedetect -f null - 2>&1 | grep _volume
  ```

  At about −91 dB `max_volume` it's silent: OBS isn't monitoring into "OBS Mic
  Feed" (see [After a rebuild](#after-a-rebuild-that-changes-the-virtual-mic) and
  the audio settings above). If it has level, check that "OBS Mic Feed" hasn't
  become the default output in GNOME's sound menu.

Then try a real call: Google Meet's preview ("Check your audio and video"), or
`zoom.us/test`. For a new setup, leave a test call running 30–60 minutes to catch
the phone overheating or Wi-Fi dropping out.

## Before each call

1. Deck plugged in, and set not to suspend while plugged in (GNOME Settings →
   Power).
2. Phone on its charger, Do Not Disturb on, DroidCam app open.
3. OBS, then **Start Virtual Camera**.
4. Only then open the meeting in Firefox, and pick **OBS Cam**, **OBS Mic** and
   the headphones. Firefox reads the device list when the page asks for it; if a
   device is missing, reload. A site where "Remember this decision" was ticked
   keeps its old choice until the permission is cleared from the address bar.
