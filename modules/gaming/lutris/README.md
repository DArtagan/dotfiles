# Pinball Science (DK Multimedia, 1998)

Notes from getting this CD-ROM title running under Wine on `thenixbeast`, so the analysis
doesn't have to be redone.

**Working setup**: prefix at `~/Games/pinball-science`, registered in Lutris as
`pinball-science` with a desktop entry at
`~/.local/share/applications/net.lutris.pinball-science.desktop`. Launch from the Lutris UI,
the app menu, or:

```bash
lutris lutris:rungame/pinball-science
```

To rebuild — mount the ISO (**both** commands; `loop-setup` alone only creates the device,
it does not mount), run the installer, then unmount:

```bash
udisksctl loop-setup -r -f ~/Downloads/"Pinball Science.iso"   # prints /dev/loopN
udisksctl mount -b /dev/loopN                                  # -> /run/media/$USER/DKMMTWSW

# GAMEDIR defaults to ~/Games/pinball-science — the LIVE prefix. Set it to
# install somewhere else, e.g. to test without touching a working install:
GAMEDIR="$HOME/Games/pinball-science" \
  ./modules/gaming/lutris/install-pinball-science.sh "/run/media/$USER/DKMMTWSW"

udisksctl unmount -b /dev/loopN && udisksctl loop-delete -b /dev/loopN
```

Neither `udisksctl` command needs root or prompts for authentication. The run takes about
**10 seconds** and is **fully unattended** — no clicks, and no windows. (The virtual desktop
is deliberately enabled as the very last step; enabling it earlier makes every subsequent
`wine` call pop up a Wine Desktop window and steal focus.) Unmounting afterwards matters —
see the drive-letter note below.

Requires `wine`, `wineboot`, `curl`, `unzip`, `python3`, `findmnt`, and network access to
GitHub for cnc-ddraw.

**This is not a from-scratch wipe.** Every step is skip-guarded, so pointing the script at
an existing prefix reuses the bundled disc, QuickTime and cnc-ddraw rather than reinstalling
them. For a genuinely clean rebuild, delete the target first:

```bash
rm -rf "$GAMEDIR"
```

**Shell variables used throughout this document.** Set these before copy-pasting any snippet
below:

```bash
GAMEDIR="$HOME/Games/pinball-science"
GAME="$GAMEDIR/drive_c/Program Files/DK Multimedia's/Pinball Science"
export WINEPREFIX="$GAMEDIR"
```

That rebuilds the prefix but does **not** create the Lutris entry. To register it, either
run `lutris -i modules/gaming/lutris/pinball-science.yml`, or add it against an existing
prefix from the Lutris UI (*+* → *Add locally installed game*) with runner `wine`, the exe
below, prefix `~/Games/pinball-science`, and Wine options `Desktop=true`,
`WineDesktop=640x480`, version *System*. The current entry was made the second way; its
config lives in `~/.local/share/lutris/games/`.

## What the disc actually needs

Determined by inspecting the ISO (`file`, import tables via `strings`, `setup.pkg`,
`dkres.ini`) rather than by trial and error:

- **`dkcode/mscience.exe` is a 32-bit PE.** No DOSBox or emulator needed — plain Wine.
- **Graphics are DirectDraw only.** `mscience.exe` / `pingame.dll` import `DDRAW.dll`,
  `DINPUT.dll`, `WINMM.dll`. There is **no Direct3D**. The `dksetup/directx/` tree on the
  disc is a generic DirectX 5 redistributable the game never touches — **do not install
  it**; Wine provides everything needed.
- **QuickTime 2.1.2 for Win32 is required.** It is loaded *dynamically*, not as a blocking
  implicit import, so the game technically starts without it — but it plays no cinematics,
  which is not an acceptable result for this title. **Do not run `dksetup/qt32inst.exe`**;
  see the QuickTime section below for why, and use `extract-quicktime.py` instead.
- **`MSVCP50.dll` is a hard import** of `mscience.exe`, `pingame.dll` and `dkkernel.dll`,
  and is **not** a Wine builtin. Ship it from `dksetup/noreg/` next to the game exe.
  `msvcrt` can stay on Wine's builtin.
- **Assets live on the disc, not in the install.** `setup.pkg` copies only ~7 MB of
  `dkcode/`; the other ~157 MB (1332 `.dib`, 336 `.wav`) is read at runtime from the CD, so
  a drive letter must point at the disc contents forever.
- **The game checks the CD volume label** (`DKVCHECK.CPP` in `dkkernel.dll`). A directory
  presented as a CD-ROM drive is not sufficient on its own — it also needs the label. See
  the volume-label note below.
- **A DirectDraw wrapper (cnc-ddraw) is mandatory**, or all static artwork renders black.
  This is the big one; see the 256-color section below.

## Decisions and gotchas

**The disc is bundled to `$GAMEDIR/cd`, not mounted.** The 163 MB tree is copied off the
ISO once and mapped as drive `D:`. Nothing depends on a loop mount at play time. Keep the
original `Pinball Science.iso` somewhere as the archival master.

Sizes below are **on `thenixbeast`'s ZFS, which has compression enabled** — on a filesystem
without it, budget the apparent sizes:

| | apparent | on disk (ZFS) |
|---|---|---|
| bundled disc (`$GAMEDIR/cd`) | 163 MB | 78 MB (~2.1:1) |
| whole prefix (`$GAMEDIR`) | ~753 MB | ~245 MB |

**The disc's own installer does not work — install by copying files.** `setup.exe` /
`dksetup/setup2.exe` are 16-bit NE binaries. `wineWow64Packages.stagingFull` does load the
16-bit subsystem (`krnl386.exe16`, `user.exe16`, `sound.drv16` all map), but `winevdm.exe`
crashes immediately on this title with no backtrace. This is not fatal: `setup.pkg`
documents exactly what the installer would have copied, so `install.sh` reproduces it
directly. A side benefit is that the install becomes fully non-interactive.

Because the installer never runs, **no DK registry keys are created**, and the game does not
need them — it resolves its assets relative to its own directory and drive `D:`. Don't go
hunting for missing registry state; that was a dead end.

**Use the System (wine) runner, not `wine-ge`.** wine-ge is Proton-derived; the system
runner is the flake's `wineWow64Packages.stagingFull`, and tracking nixpkgs means it updates
with `nh os switch .` rather than rotting as a pinned download.

**The prefix is win64, not win32.** `wineWow64Packages` is a new-WoW64 build and rejects
`WINEARCH=win32` outright:

```
wine: WINEARCH is set to 'win32' but this is not supported in wow64 mode
```

The 32-bit game runs inside the win64 prefix via the WoW64 thunk. This has one important
consequence: **32-bit registry keys land under `WOW6432Node`**. Any `reg add` aimed at the
game must use `/reg:32`, or the game will not see it. This is what silently broke audio the
first time around.

**Audio needs the ACM codecs registered manually.** A fresh prefix has no
`Drivers32` key at all, so `msacm.msadpcm` fails to load and the disc's ADPCM `.wav` assets
are silent. The installer script writes the mappings with `/reg:32`.

**Drive letters: unmount the ISO once the disc is bundled.** While the ISO stays mounted,
Wine's mount manager re-adds a drive for it (`f: -> /run/media/$USER/DKMMTWSW`) on **every**
`wine` invocation. Deleting the entry does not stick: the next `wine` call recreates it, and
the letter isn't stable across runs. The install script therefore clears stray letters both
mid-run and again as its final step, but that only holds until the next launch. Unmount the
ISO — the disc is bundled at `$GAMEDIR/cd` and the mount has no further purpose:

```bash
udisksctl unmount -b /dev/loopN && udisksctl loop-delete -b /dev/loopN
```

**Unmounting only prevents re-creation — it does not remove drives that already exist.** If
you launched the game even once while the ISO was mounted (e.g. to check the install
worked), you are left with a permanently dangling `F:` pointing at a gone mount, plus a
stale `"f:"="cdrom"` registry value. Clear them by hand:

```bash
rm -f "$GAMEDIR"/dosdevices/[efgh]: "$GAMEDIR"/dosdevices/[efgh]::
for L in e f g h; do wine reg delete 'HKLM\Software\Wine\Drives' /v "$L:" /f; done
```

Note `e:: -> /dev/sr0` is also recreated on every start because this machine has a physical
optical drive. It's harmless — there's no `e:` symlink, so no E: drive exists — but it means
"only `D:` exists" is never literally true.

**How bad is a stray drive? Less than originally thought.** The original debugging detour
saw the game read assets from `F:` (the case-strict iso9660 mount, `check=s,map=n`) where
every uppercase lookup failed:

```
CreateFileW L"F:\ONLINE\ONMENU.DIB"
NtCreateFile L"\??\F:\INTRO\ZQT1001P.PNG" not found (c0000034)
```

Note only the `F:\...\ONMENU.DIB` line above is evidence of anything. **The `.PNG`
not-found is benign** and was wrongly cited here originally: the engine routinely probes for
a `.PNG` before falling back to `.DIB`, so a fully working install produces ~21 identical
`.PNG` not-founds on `D:`. Don't chase them.

A later audit could **not** reproduce the drive problem: with `F:` present and the ISO
mounted, the game opened all 24 `.dib` files from `D:` with zero `F:` references in a
13 MB `+file` trace.
The difference is almost certainly the **volume label** — in the original failure `D:` had no
`.windows-label`, so it failed the `DKVCHECK` volume test and the game fell through to the
only other CD-ROM carrying the `DKMMTWSW` label, which was the real mount. That makes the
label the actual fix and the drive-clearing belt-and-braces. Treated as inference, not
proven: the failing configuration wasn't re-created to confirm it.

Verify either way with `WINEDEBUG=+file` — there should be zero `.dib` not-founds.

**The disc needs its volume label.** The game runs a volume check (`DKVCHECK.CPP` in
`dkkernel.dll`) and otherwise puts up *"Please put Pinball Science in a CD/DVD drive"*. A
directory-backed Wine drive has no label, so create one — the label from the ISO's primary
volume descriptor is **`DKMMTWSW`**:

```bash
printf 'DKMMTWSW\n' > "$GAMEDIR/cd/.windows-label"
rm -f "$GAMEDIR/dosdevices/d::"   # so Wine reads the label file, not a device
```

Confirm with `wine cmd /c 'vol d:'`.

**Do _not_ set `renderer=gdi`.** It looks like a plausible fix for a 2D DirectDraw title and
is actively harmful — it triggers `err:winediag:wined3d_dll_init Disabling 3D support`.
Leave `HKCU\Software\Wine\Direct3D` alone. The `err:d3d:context_choose_pixel_format` warning
on the default path is benign.

**Black bars around the intro movie are normal** — the `.mov` clips are smaller than 640x480.

**First launch requires creating a profile.** The game opens on a launch screen needing a
click in the centre to start, plays its intro (click again to skip), then reaches the main
menu. From there everything is gated behind a modal *"PLEASE TYPE YOUR NAME"* prompt — you
must create a user and pick a quiz difficulty before any content is reachable. This trips up
automated testing in particular, since it needs actual keyboard input.

## QuickTime: extract it, don't run the installer

`dksetup/qt32inst.exe` is a GUI installer, and it used to be the single blocking step in an
otherwise unattended install. Extracting instead removes the interaction entirely.

**Do not close its window manually if you ever do run it.** An earlier version of this
document said the installer "does not exit on its own" and had to be closed by hand. That
was wrong, and following it *causes* the failure it claims to avoid: in a controlled run the
installer completed unattended in ~12 seconds, wrote `QTIM32.DLL` and `CMGR32.DLL`, recorded
`Complete=1` in `drive_c/windows/RESULT.QTW`, and exited 0 on its own. Closing the window
instead leaves `Complete=0` and **no DLLs at all**, after which the game reports *"QuickTime
could not be initialized… videos will not play."* The apparent "hang" is the Wine desktop
window lingering, not the installer.

If you use the GUI fallback, check the result — the installer records it explicitly:

```bash
cat "$GAMEDIR/drive_c/windows/RESULT.QTW"    # want: Complete=1
```

`extract-quicktime.py` replaces it entirely and needs no GUI, no Wine, and no dependencies
beyond Python 3:

```bash
./extract-quicktime.py "$GAMEDIR/cd/dksetup/qt32inst.exe" "$GAMEDIR/drive_c"
```

**How it works.** qt32inst.exe stores its payload as **27 SZDD-compressed members**
(Microsoft's old `COMPRESS.EXE` LZ77 format) laid out contiguously in the PE resource
section — resource type `256`, in ~30 KB chunks. Because they are contiguous, they can be
found by scanning the raw `.exe` for the `SZDD\x88\xf0\x27\x33` magic and decompressed
directly; no PE parsing and no 7z required. Each member's header carries its uncompressed
length, and the script checks every output against the size **and MD5** that a real run of
the installer produces.

**The counts, since three different numbers are easy to confuse:** the payload holds **27**
SZDD members, all 27 verified byte-identical against a real installer run. The script also
writes **`QTW.INI`**, for **28** files on disk. Of those, **26** are game-relevant — the
27th member is `QTW32DEL.EXE`, QuickTime's own uninstaller, which nothing uses.

One caveat on "verified": `QTW.INI` is written from a literal in the script (with CRLF line
endings, to match byte-for-byte) and is only created `if not os.path.exists(...)`. It is the
one file **not** md5-checked, so the verification guarantee covers the 27 extracted members.

**What it installs, and why all of it matters.** Not just `QTIM32.DLL`. The `.QTC` files are
the actual **codecs**, and without them the cinematics cannot decode:

| Kind | Files |
|---|---|
| Core | `QTIM32.DLL`, `CMGR32.DLL` (Component Manager), `QTOLE32.DLL`, `QTWMCI32.DLL`, `HNDLR32.DLL` |
| Codecs | `CVID32.QTC` (Cinepak), `JPEG32.QTC`, `RLE32.QTC`, `IV32QT32.QTC` (Indeo), `RPZA32.QTC`, `SMC32.QTC`, `RAW32.QTC`, `MC32.QTC`, `NAVG32.QTC`, `DCI32.QTC`, `DHIO32.QTC` |
| Support | `QTW32.CPL`, `QTWCP.HLP`, `MCIQTENU.Q32`, `PLAY32.EXE`, `VIEW32.EXE`, help files |

The full manifest also appears in the prefix registry under
`Software\...\QuickTime32\CurrentVersion\SharedFiles`, which is how the mapping was
confirmed. The registry entries themselves are not needed — the game links `QTIM32.DLL`
directly, and the Component Manager finds `.QTC` codecs by scanning the system directory.

The script targets `syswow64` in a win64 prefix and `system32` in a win32 one, and refuses
to run if the installer doesn't contain exactly 27 members (i.e. a different QuickTime
build), falling back to the GUI rather than writing something wrong.

## The 256-color problem — SOLVED with cnc-ddraw

**This is the single thing that makes the game playable.** Without it, the intro movies play
with sound and the menus respond to clicks, but every static background renders black.

**Fix: drop [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw) into the game directory as
a native `ddraw.dll` override.** `install.sh` does this. It supplies its own full 256-entry
emulated palette, which is exactly what Wine cannot provide (see the diagnosis below).

```bash
cp ddraw.dll ddraw.ini "$GAME/"          # from cnc-ddraw.zip, v7.1.0.0 verified
cp -r Shaders "$GAME/"
wine reg add 'HKCU\Software\Wine\DllOverrides' /v ddraw /d 'native,builtin' /f
```

Stock `ddraw.ini` defaults work as-is — no tuning needed.

**Use cnc-ddraw, not DDrawCompat.** DDrawCompat v0.7.1 is the better-known wrapper for this
class of problem on Windows, but it crashes instantly under Wine with a null-pointer read
(`page fault on read access to 0x00000000`, backtrace through `ddraw+0x1b93d9`) because it
hooks Windows internals Wine doesn't implement. cnc-ddraw is developed with Wine/Linux
support in mind and works first try.

Two cosmetic quirks remain, both harmless: the "New User" screen can briefly show a white
background and a leftover video clip fragment, which resolve on their own after a moment.

### Why it was broken — the underlying diagnosis

Worth keeping, because it explains why no amount of Wine configuration helps.

A `WINEDEBUG=+ddraw` trace shows:

```
ddraw2_SetCooperativeLevel flags 0x13   (DDSCL_FULLSCREEN | DDSCL_EXCLUSIVE | DDSCL_ALLOWREBOOT)
ddraw2_SetDisplayMode      width 640, height 480, bpp 8
```

…followed by **no further DirectDraw calls at all** — no `CreateSurface`, no `Blt`. The game
uses DirectDraw only to switch into a 640x480 **256-color** mode, then paints its DIBs
through GDI against a realized logical palette. A `WINEDEBUG=+palette` trace confirms the
game does its part correctly:

```
  8  NtGdiCreatePaletteInternal
 61  NtUserRealizePalette
350  NtUserSelectPalette
256  set_palette_entries
```

Wine receives all of it and still renders black. The precise mechanism is visible in a
`WINEDEBUG=+palette` trace — the game reads system palette entries in this pattern:

```
get_system_palette_entries start=0, start=246
get_system_palette_entries start=1, start=247
get_system_palette_entries start=2, start=248   … through 9/255
NtGdiCreatePaletteInternal entries=20
NtGdiCreatePaletteInternal entries=256
```

Indices 0–9 and 246–255 are Windows' reserved **static** palette entries. Reading exactly
those 20, then building a 256-entry palette around them, is the textbook **identity
palette** construction: match the static entries at both ends so that `RealizePalette`
yields a 1:1 index→hardware-palette mapping and 8-bit blits are exact. The DIBs themselves
are then blitted with `coloruse=0` (`DIB_RGB_COLORS`) via `StretchDIBits` out of 8bpp
`CreateDIBSection` surfaces.

This requires a real 256-entry hardware palette to realize into. Wine's X11 and Wayland
drivers only provide a 32-bit TrueColor desktop, where the only meaningful system palette
entries are the 20 static ones — so the identity mapping collapses. The ~236 custom colours
resolve to black; any pixel that happens to use one of the 20 static colours renders
correctly.

**The visible signature confirms it**: backgrounds are black, but interactive elements show
a light smattering of dots (pixels drawn in static colours), and animated widgets flash a
white border while expanding that vanishes once they repaint in custom palette colours.

The legacy `ScreenDepth` / `PrivateColorMap` registry knobs that used to force an 8-bit X
visual are gone from Wine and absent from the 11.14 build, so there is no way to give it a
real palettized visual. Note this is not Wine-specific — Windows itself dropped true
palettized display modes after XP/DWM, which is precisely why wrappers like cnc-ddraw exist
in the first place. cnc-ddraw fixes it by maintaining its own emulated 256-entry palette and
compositing the result itself, sidestepping the host's palette support entirely.

### Dead ends — don't retry these

All tested against the fully-corrected configuration, all still black:

- **Virtual desktop size** — 800x600 and 640x480 behave identically.
- **A timing/race condition** — a run under heavy `WINEDEBUG=+file` tracing (5.8 MB of log,
  drastically slower) produces a pixel-identical black screen.
- **Leftover display state from a previous process** — a crash leaving the desktop alive
  looked like it correlated with a working run. It doesn't: neither suspending a first
  instance (`SIGSTOP`) nor holding the desktop open with a standalone
  `wine explorer /desktop=` across two runs changes anything.
- **Every `wined3d` renderer backend** — `renderer=gdi` and `renderer=no3d`. `no3d` is the
  decisive one: no 3D device is created at all, so no OpenGL or Vulkan surface exists to
  composite over the GDI content, and it is still black. The graphics backend is not the
  variable.
- **The Wayland driver** (`HKCU\Software\Wine\Drivers` `Graphics=wayland`) — same black
  background, and it loses virtual-desktop scaling too.
- **Classic 32-bit Wine in a true `WINEARCH=win32` prefix** (`wineWowPackages.stagingFull`)
  — identical. Wine's GDI/palette code is shared between the two builds; only the WoW64
  thunking layer differs.
- **DDrawCompat** — crashes, see above.

## Harmless noise in the logs

Not worth chasing:

- `Failed to load module L"DKShresD.dll"` — the debug-suffixed variant; falls back to `dkshres.dll`.
- `err:mmio:MMIO_InstallIOProc Cannot remove a mmIOProc while in use`.
- `libEGL warning: egl: failed to create dri2 screen` / `pci id ... driver (null)` — nvidia noise on every Wine invocation.
- `LdrGetProcedureAddress "__wine_spec_main_module" ... krnl386.exe16` — normal for the 16-bit subsystem.
