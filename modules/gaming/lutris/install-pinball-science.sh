#!/usr/bin/env bash
# Build a working Pinball Science (DK Multimedia, 1998) Wine prefix from the CD.
#
# Usage:  install-pinball-science.sh [SOURCE]
#   SOURCE  mounted disc or an already-bundled copy
#           (default: /run/media/$USER/DKMMTWSW, where udisks mounts it)
#
# Mount the ISO first — BOTH commands are needed, loop-setup alone only creates
# the device, it does not mount it:
#   udisksctl loop-setup -r -f "Pinball Science.iso"     # prints /dev/loopN
#   udisksctl mount -b /dev/loopN                        # mounts it
#
# Needs: wine, curl, unzip, python3, and network access to GitHub (cnc-ddraw).
#
# See README.md in this directory for why each step is here.
set -euo pipefail

SOURCE="${1:-/run/media/$USER/DKMMTWSW}"
GAMEDIR="${GAMEDIR:-$HOME/Games/pinball-science}"
GAME="$GAMEDIR/drive_c/Program Files/DK Multimedia's/Pinball Science"

for dep in wine wineboot curl unzip python3; do
	command -v "$dep" >/dev/null || {
		echo "error: missing required command: $dep" >&2
		exit 1
	}
done

export WINEPREFIX="$GAMEDIR"
export WINEDEBUG="${WINEDEBUG:--all}"
# Not a win32 prefix: wineWow64Packages is new-WoW64 and rejects WINEARCH=win32.
unset WINEARCH

if [ ! -f "$SOURCE/dkcode/mscience.exe" ]; then
	echo "error: $SOURCE does not look like the Pinball Science disc" >&2
	exit 1
fi

# 1. Bundle the disc so nothing depends on a loop mount at play time.
#    iso9660 exports everything read-only; the copy must be writable.
#    Guarded by a marker written only after the copy succeeds — guarding on any
#    single copied file would make an interrupted 163 MB copy look complete
#    forever, since this step is skipped on every later run.
if [ ! -f "$GAMEDIR/cd/.bundle-complete" ]; then
	echo "==> Bundling disc to $GAMEDIR/cd (163 MB)"
	rm -rf "$GAMEDIR/cd"
	mkdir -p "$GAMEDIR/cd"
	cp -r --no-preserve=mode "$SOURCE/." "$GAMEDIR/cd/"
	chmod -R u+w "$GAMEDIR/cd"
	touch "$GAMEDIR/cd/.bundle-complete"
else
	echo "==> Disc already bundled, skipping copy"
fi

# 2. Create the prefix.
echo "==> Creating prefix"
WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -u

# 3. Windows 98, and a 640x480 virtual desktop matching the mode the game
#    requests via SetDisplayMode(640,480,8). This does NOT fix the black
#    backgrounds (see the known-broken section in README.md) — it just avoids a
#    real 640x480x8 mode switch on a 4K output.
echo "==> Configuring Windows 98"
wine reg add 'HKCU\Software\Wine' /v Version /d win98 /f
# The virtual desktop is deliberately NOT enabled here — it only matters when the
# game runs, and turning it on now would make every subsequent `wine` call in this
# script pop up a Wine Desktop window and steal focus. Enabled in step 10 instead.

# 4. Present the bundled disc as CD-ROM drive D:. The game reads ~157 MB of
#    .dib/.wav assets from the disc at runtime; only ~7 MB gets installed.
#
#    Every other drive letter must be cleared. If the ISO is still mounted,
#    wineboot auto-detects it and the game reads assets from that drive instead
#    — where uppercase lookups fail, because iso9660 is mounted check=s over
#    lowercase names. No d:: device link, so Wine reads .windows-label below.
echo "==> Mapping D: to the bundled disc"
for L in d e f g h; do
	rm -f "$GAMEDIR/dosdevices/$L:" "$GAMEDIR/dosdevices/$L::"
	wine reg delete 'HKLM\Software\Wine\Drives' /v "$L:" /f >/dev/null 2>&1 || true
done
ln -sfn "$GAMEDIR/cd" "$GAMEDIR/dosdevices/d:"
wine reg add 'HKLM\Software\Wine\Drives' /v 'D:' /d cdrom /f

# 5. The game runs a volume-label check (DKVCHECK.CPP) and otherwise demands
#    "Please put Pinball Science in a CD/DVD drive". DKMMTWSW is the volume id
#    from the ISO's primary volume descriptor.
echo "==> Setting the CD volume label"
printf 'DKMMTWSW\n' >"$GAMEDIR/cd/.windows-label"

# 6. Register the ACM codecs. A fresh prefix has no Drivers32 key at all, so
#    msacm.msadpcm fails to load and the disc's ADPCM audio is silent.
#    /reg:32 is mandatory: this is a win64 prefix and the game is 32-bit, so
#    without it the keys land outside WOW6432Node where the game cannot see them.
echo "==> Registering ACM audio codecs"
for pair in \
	"msacm.imaadpcm=imaadp32.acm" \
	"msacm.msadpcm=msadp32.acm" \
	"msacm.msg711=msg711.acm" \
	"msacm.msgsm610=msgsm32.acm" \
	"msacm.l3acm=l3codeca.acm" \
	"wavemapper=msacm32.drv"; do
	wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Drivers32' \
		/v "${pair%%=*}" /d "${pair#*=}" /reg:32 /f
done

# 7. Install the game by copying. The disc's 16-bit InstallShield stub crashes
#    winevdm; setup.pkg documents exactly what it would have copied anyway.
#    msvcp50.dll is a hard import and is not a Wine builtin. Do NOT copy the
#    msvcrt.dll sitting beside it — Wine's builtin is the one we want.
echo "==> Installing game files"
mkdir -p "$GAME"
cp "$GAMEDIR/cd/dkcode/"* "$GAME/"
cp "$GAMEDIR/cd/dksetup/noreg/msvcp50.dll" "$GAME/"

# 8. QuickTime 2.1.2 — required. The game's cinematics need it, and the .QTC
#    codecs it ships (Cinepak, JPEG, RLE, Indeo, ...) are what decode them.
#    Extracted straight out of qt32inst.exe rather than running the disc's GUI
#    installer, which was the one interactive step here. extract-quicktime.py
#    verifies every file against the size and md5 the real installer produces,
#    and only writes once all 27 have been verified — so this guard cannot be
#    satisfied by a half-finished extraction.
if [ -f "$GAMEDIR/drive_c/windows/syswow64/QTIM32.DLL" ] ||
	[ -f "$GAMEDIR/drive_c/windows/system32/QTIM32.DLL" ]; then
	echo "==> QuickTime already installed, skipping"
else
	echo "==> Installing QuickTime 2.1.2 (extracted, no GUI)"
	if ! "$(dirname "$0")/extract-quicktime.py" \
		"$GAMEDIR/cd/dksetup/qt32inst.exe" "$GAMEDIR/drive_c"; then
		echo "    extraction failed — falling back to the GUI installer." >&2
		echo "    Let it finish by itself; do NOT close its window, that aborts it." >&2
		(cd "$GAMEDIR/cd/dksetup" && wine qt32inst.exe)
	fi
fi

# Verify QuickTime actually landed — the GUI installer can report success while
# leaving nothing behind, and a broken QuickTime means no cinematics.
if [ ! -f "$GAMEDIR/drive_c/windows/syswow64/QTIM32.DLL" ] &&
	[ ! -f "$GAMEDIR/drive_c/windows/system32/QTIM32.DLL" ]; then
	echo "error: QuickTime install failed — QTIM32.DLL is missing." >&2
	if [ -f "$GAMEDIR/drive_c/windows/RESULT.QTW" ]; then
		echo "       $(cat "$GAMEDIR/drive_c/windows/RESULT.QTW")" >&2
	fi
	echo "       The game will run but play no cinematics. Re-run this script." >&2
	exit 1
fi

# 9. cnc-ddraw — THE fix for the black backgrounds. The game switches to a
#    640x480 256-colour mode and paints DIBs through GDI against an identity
#    palette; Wine's TrueColor desktop has no 256-entry system palette to
#    realize into, so all custom colours resolve to black. cnc-ddraw supplies
#    its own emulated palette. Use cnc-ddraw, NOT DDrawCompat — the latter
#    crashes under Wine. See README.md.
echo "==> Installing cnc-ddraw (required — without it all artwork is black)"
CNC_VER="${CNC_VER:-v7.1.0.0}"
CNC_URL="https://github.com/FunkyFr3sh/cnc-ddraw/releases/download/$CNC_VER/cnc-ddraw.zip"
# Check every artifact, not just ddraw.dll: guarding on the DLL alone means a
# missing ddraw.ini or Shaders/ would never be repaired by a re-run.
if [ ! -f "$GAME/ddraw.dll" ] || [ ! -f "$GAME/ddraw.ini" ] || [ ! -d "$GAME/Shaders" ]; then
	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT
	curl -fsSL --retry 3 -o "$TMP/cnc.zip" "$CNC_URL"
	unzip -q -o "$TMP/cnc.zip" -d "$TMP/cnc"
	cp "$TMP/cnc/ddraw.dll" "$TMP/cnc/ddraw.ini" "$GAME/"
	cp -r "$TMP/cnc/Shaders" "$GAME/"
else
	echo "    already present, skipping download"
fi
# Prefer the wrapper next to the exe over Wine's builtin ddraw
wine reg add 'HKCU\Software\Wine\DllOverrides' /v ddraw /d 'native,builtin' /f

# 10. Re-assert the drive layout LAST. Step 4 alone is not enough: every `wine`
#     invocation after it re-runs the mount manager, and if the source ISO is
#     still mounted Wine re-adds a drive for it (as f:, g:, ... — the letter is
#     not stable). Steps 6-9 fire ~8 wine calls, so the stray drive is always
#     back by the end. Clearing here leaves the prefix in the documented state.
echo "==> Re-clearing stray drives"
for L in e f g h; do
	rm -f "$GAMEDIR/dosdevices/$L:" "$GAMEDIR/dosdevices/$L::"
	wine reg delete 'HKLM\Software\Wine\Drives' /v "$L:" /f >/dev/null 2>&1 || true
done

# Enable the 640x480 virtual desktop last, so none of the wine calls above
# spawned a desktop window. Matches the game's SetDisplayMode(640,480,8) and
# avoids a real mode switch on a 4K output.
echo "==> Enabling 640x480 virtual desktop"
wine reg add 'HKCU\Software\Wine\Explorer\Desktops' /v Default /d 640x480 /f
wine reg add 'HKCU\Software\Wine\Explorer' /v Desktop /d Default /f

if findmnt -no TARGET -- "$SOURCE" >/dev/null 2>&1; then
	echo
	echo "NOTE: $SOURCE is still mounted. The disc is now bundled at \$GAMEDIR/cd and"
	echo "      the mount is no longer needed. Leaving it mounted lets Wine re-add a"
	echo "      stray drive for it on the next launch. Unmount with:"
	echo "        udisksctl unmount -b /dev/loopN && udisksctl loop-delete -b /dev/loopN"
fi

echo
echo "Done. Launch with:"
echo "  WINEPREFIX='$GAMEDIR' wine '$GAME/mscience.exe'"
