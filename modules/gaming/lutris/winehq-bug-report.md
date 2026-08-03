# WineHQ bug report — ready to submit

File at <https://bugs.winehq.org/> (see "How to submit" at the bottom of this file).

---

**Product:** Wine
**Component:** ntdll (see note — the responsible component is not yet pinned down)
**Version:** 11.14 (also reproduced on the classic non-WoW64 build of the same version)
**Severity:** normal
**Platform:** x86-64 / Linux 6.18.40

## Summary

Pinball Science (DK Multimedia, 1998) intermittently hangs with one core pinned at 100%.
The main thread spins in `NtYieldExecution` waiting on a condition that never becomes true,
while every other thread in the process sits idle.

## Description

Pinball Science is a 32-bit Win9x-era CD-ROM title. After a few minutes of normal play the
UI stops responding. Parts of the game keep drawing and some controls still react, but the
program never recovers. It is not a deadlock: the main thread is `R` (running) and busy, and
the process burns 100% of one core indefinitely.

The hang correlates strongly with **concurrent sound playback**. Reducing the game's own
in-game audio settings (Options → sound level / narration) makes it largely go away, and
raising them again brings it back. It is not tied to any one sound file or codec.

## Steps to reproduce

1. Install Pinball Science (DK Multimedia, 1998) into a 64-bit prefix, Windows 98 mode
2. Play normally with the game's sound options turned up
3. Within a few minutes the UI stops responding while a core stays pinned

Intermittent — there is no known deterministic trigger. It is more frequent with more
simultaneous sounds.

## Observed behaviour

Two distinct spin signatures have been captured. Both are the same visible symptom.

**Signature A — pure yield spin** (`strace -c -p <pid>`, 6s):

```
% time     seconds  usecs/call     calls    errors syscall
 63.50    0.277441           0    643178           getrusage
 32.78    0.143245           0    321589           sched_yield
  1.46    0.006387           1      6364           read
  0.78    0.003422           0      9396           rt_sigprocmask
  0.59    0.002589           0      4344           write
```

`getrusage` has a single caller in Wine — `NtYieldExecution` in `dlls/ntdll/unix/sync.c`,
which calls it twice per yield. 643178 / 321589 = 2.0 exactly, so the entire profile is
`SwitchToThread()` / `Sleep(0)` being called ~320,000 times per second. The wait condition
itself is evaluated in user space and makes no syscalls.

**Signature B — message-pump spin** (a different occurrence, same symptom):

```
 28.76    0.203367           0    321435           rt_sigprocmask
 26.00    0.183840           0    241077           read           (wineserver IPC)
 21.93    0.155075           0    160718           write
 15.40    0.108903           0    160717           getrusage
  7.89    0.055814           0     80358           sched_yield
```

Here the loop also round-trips to the wineserver, consistent with `PeekMessage` on an empty
queue. `voluntary_ctxt_switches` reached 140 million.

**Thread states during the hang** — only the main thread is busy:

```
1483070  R   mscience.exe      -                   cpu=7731
1483660  S   wine_dsound_mix   anon_pipe_read      cpu=3
1483072  S   wine_mmdevapi_n   anon_pipe_read      cpu=0
1483085  S   mscienc:disk$0    futex_do_wait       cpu=0     (x4)
1483111  S   CPMMListener      poll_schedule_...   cpu=1
...
```

**DirectSound activity immediately before the hang** (`WINEDEBUG=+dsound`). Playback works
normally and is shut down cleanly; the hang happens afterwards, outside dsound:

```
GetCurrentPosition  playpos = 52450, writepos = 52890, buflen=80960
GetCurrentPosition  playpos = 52920, writepos = 53360, buflen=80960   <- advancing normally
IDirectSoundBufferImpl_Unlock            (0037E1D0,01F7FD50,8820,00000000,0)
IDirectSoundBufferImpl_Stop              (0037E1D0)
IDirectSoundBufferImpl_SetCurrentPosition(0037E1D0,0)
IDirectSoundBufferImpl_SetCurrentPosition(0037E1D0,0)
   <- the game thread issues no further DirectSound calls; the mixer keeps running
```

The application streams into a looping secondary buffer (8820-byte chunks, 22050 Hz 16-bit
mono, 80960-byte buffer) and polls `GetCurrentPosition`. It uses no `IDirectSoundNotify`.
Audio remains healthy throughout — PipeWire shows a live, active stream for the process.

## Ruled out

- **Audio backend.** Reproduces on `winepulse` and on `winealsa`.
- **Audio hardware.** Reproduces on a USB DAC and on a PCI HDMI sink.
- **DirectSound implementation.** Reproduces with Wine's builtin dsound and with native
  DirectSound (`winetricks dsound`, MS DirectX 9.0c `dsound.dll`, confirmed loaded native).
- **Codec / media.** Occurs with both MS-ADPCM and 16-bit PCM sources. All source files
  parse cleanly and were verified byte-for-byte against the original disc image.
- **Graphics.** Zero GPU syscalls during the spin. Reproduces with wined3d `renderer=gdi`
  and `renderer=no3d` (no 3D device created at all), and on both the X11 and Wayland
  drivers. (The title uses a `ddraw.dll` wrapper, cnc-ddraw, for unrelated palette reasons;
  the hang predates and is independent of it.)
- **Wine build type.** Reproduces on the new-WoW64 build and on a classic 32-bit build in a
  true `WINEARCH=win32` prefix.
- **Deadlock.** Not blocked — main thread `R` and busy, all others idle.

## What I could not determine

The user-space condition the main thread is waiting on. Two debuggers were tried:

- `gdb` attaches and detaches cleanly but cannot unwind across the WoW64 boundary; it only
  resolves host-side frames (`libc`, `ntdll.so`), never the 32-bit application code. Verified
  against a healthy process — the output is identical, so it is not discriminating.
- `winedbg --command "attach <pid>"` **reproducibly faults on attach and kills the target**,
  at byte-identical offsets across separate occurrences:

  ```
  Unhandled exception: page fault on read access to 0xfff310fc in wow64 32-bit code
  =>0 0x7a5036f6 in krnl386.exe16 (+0x336f6)
    1 0x7a4e8514 in krnl386.exe16 (+0x18514)
    2 0x7bf81c80 in ntdll (+0x51c80)
  ```

  This may be a separate winedbg/WoW64 bug worth splitting out. I cannot tell whether the
  fault reflects the target's real state or is an artefact of the attach, so I make no claim
  about it. The 16-bit subsystem is loaded in this prefix (`krnl386.exe16`, `user.exe16`,
  `sound.drv16`, `mmsystem.dll16`).

Because of that, I have not been able to identify the responsible component; `ntdll` is a
placeholder based only on where the spin bottoms out.

## Notes

`HKCU\Software\Wine\DirectSound` no longer exposes `MaxShadowSize`, `HardwareAcceleration`,
`SndQueueMax` or `SndQueueMin` in 11.14 (only `HelBuflen`), so the historical
`dsoundbug9612`-style workarounds do not apply.

Full traces can be provided. Note `WINEDEBUG=+dsound` emits roughly 150 MB/s once the hang
begins, so any attached trace needs to be bounded.

---

## How to submit

1. Create an account / log in at <https://bugs.winehq.org/>
2. **File a Bug** → Product **Wine**
3. Component: `ntdll` (say in the description that the component is a guess — a triager
   will move it)
4. Paste everything above the `---` line
5. Attach, if asked:
   - `~/pinball-freeze-*/` capture directories (thread states, syscall profiles)
   - a bounded `WINEDEBUG=+dsound` trace — regenerate with
     `modules/gaming/lutris/diagnose-freeze.sh` and the trace helper described in README.md

Before filing, search Bugzilla for existing reports — `NtYieldExecution`, `SwitchToThread`
spin, and dsound streaming hangs are all worth checking.
