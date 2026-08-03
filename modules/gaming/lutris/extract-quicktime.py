#!/usr/bin/env python3
"""Install QuickTime 2.1.2 for Windows from qt32inst.exe without running it.

The disc ships a GUI installer, which made QuickTime the one interactive step in
an otherwise unattended install. (The installer does complete and exit on its
own if left alone — closing its window is what aborts it. Extracting sidesteps
the question entirely.) QuickTime is not optional for this title: the game's
cinematics need it, and the .QTC codecs it ships (Cinepak, JPEG, RLE, Indeo,
...) are what actually decode them.

qt32inst.exe stores its payload as 27 SZDD-compressed members (Microsoft's old
COMPRESS.EXE LZ77 format) laid out contiguously in the PE resource section, so
they can be located by scanning for the SZDD magic and decompressed directly.
No PE parsing, no 7z, no external dependencies.

Every extracted file is verified against the size and MD5 produced by a real
run of the installer, so a successful run is byte-for-byte identical to what
the GUI would have written.

Usage:
    extract-quicktime.py <qt32inst.exe> <drive_c>
"""
import hashlib
import os
import struct
import sys

SZDD_MAGIC = b"SZDD\x88\xf0\x27\x33"
SZDD_HEADER_LEN = 14

# (destination, uncompressed size, md5) in payload order. "system" resolves to
# the prefix's 32-bit system directory (syswow64 in a win64 prefix).
MANIFEST = [
    ("system/QTWMCI32.DLL", 64512, "ae5afc2fa618a2a786837997c71af095"),
    ("system/MCIQTENU.Q32", 16384, "4ac2ae83162ce9c36beac1c4ae33c31f"),
    ("system/CMGR32.DLL", 32768, "c680cbd43c6799362e266aeaaea986c5"),
    ("system/MC32.QTC", 128000, "c41c4b38cebf4523db977350c8cd466b"),
    ("system/NAVG32.QTC", 35840, "ea58cf6dc6ebc5da11fdcb8d69a0f68e"),
    ("system/CVID32.QTC", 151040, "ca34c30621bc14711ea810b2243362fb"),
    ("system/IV32QT32.QTC", 83456, "4e5453a01bcc1eadf8ad6125e33a1050"),
    ("system/DCI32.QTC", 24064, "a9abafbeef19e723f3c9e894fdf90d27"),
    ("system/QTIM32.DLL", 345600, "ff095a2434540d101ba2901891d3a5a7"),
    ("system/RAW32.QTC", 20480, "a2353fedac4246a3b885e3fac181535c"),
    ("system/RLE32.QTC", 103936, "c93804035e692a6893a6482ed4f6b4bb"),
    ("system/RPZA32.QTC", 229376, "4e4b9ef08a1a5d4f698a31611d3f75b7"),
    ("system/SMC32.QTC", 165888, "bc8bc6914240b3b6e08d8296014bc8c3"),
    ("system/JPEG32.QTC", 34816, "c75ed4d52dcf1bca84277b8e3acfff85"),
    ("system/QTOLE32.DLL", 93696, "050e47ddd9dd1abec523a3508fea1404"),
    ("system/HNDLR32.DLL", 18944, "12ae15ae41830fe73b86bad3577fdc98"),
    ("system/DHIO32.QTC", 38912, "1a183961adc54b4bb3b154ab615687d8"),
    ("system/QTW32.CPL", 341504, "921f3b693237f30ee8a2f91121ff1252"),
    ("system/QTWCP.HLP", 175135, "abbbd1f4f6ff9786bec4d4f666ef7940"),
    ("windows/PLAY32.EXE", 107008, "b36bce2f0b096cb57eef732ebabbe915"),
    ("windows/VIEW32.EXE", 93184, "1acf30ef932071ed4c78614d7550a2b8"),
    ("windows/SAMPLE.MOV", 881787, "8b0a223c796c8edc84b88e0d8079c1c0"),
    ("windows/READQT32.WRI", 10112, "c5622263260ce1101e6443f75c487d65"),
    ("windows/MCENU.HLP", 43875, "a0004d2ec6c05f6640210b861c6efba0"),
    ("windows/PLAYENU.HLP", 67415, "4794c924c75c81c39c453175d11639c7"),
    ("windows/VIEWENU.HLP", 36412, "77859b1865a3bfcf1a14415e4f45d829"),
    ("windows/QTW32DEL.EXE", 169472, "e42be7fc743454e9af0efe2e4eac98d1"),
]

# Written by the real installer; harmless defaults that disable hardware paths
# QuickTime cannot probe reliably under Wine.
QTW_INI = """[Sound 32]
DisableAutoRateAdjust=1
[QuickTime for Windows 32]
Surface Component=None
Video Hardware Stretch=Not directly supported
VHDW Component=None
Video Hardware=Not directly supported
"""


def szdd_decompress(data, outlen):
    """Decompress an SZDD ('A' variant) stream: LZ77 over a 4K ring buffer."""
    window = bytearray(b"\x20" * 4096)
    pos = 4096 - 16
    out = bytearray()
    i = 0
    while i < len(data) and len(out) < outlen:
        control = data[i]
        i += 1
        for bit in range(8):
            if len(out) >= outlen or i >= len(data):
                break
            if control & (1 << bit):
                ch = data[i]
                i += 1
                out.append(ch)
                window[pos] = ch
                pos = (pos + 1) % 4096
            else:
                if i + 1 >= len(data):
                    break
                lo, hi = data[i], data[i + 1]
                i += 2
                mpos = lo | ((hi & 0xF0) << 4)
                mlen = (hi & 0x0F) + 3
                for _ in range(mlen):
                    if len(out) >= outlen:
                        break
                    ch = window[mpos % 4096]
                    mpos += 1
                    out.append(ch)
                    window[pos] = ch
                    pos = (pos + 1) % 4096
    return bytes(out)


def find_members(raw):
    offsets = []
    start = 0
    while True:
        i = raw.find(SZDD_MAGIC, start)
        if i < 0:
            break
        offsets.append(i)
        start = i + 1
    return offsets


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    installer, drive_c = sys.argv[1], sys.argv[2]

    raw = open(installer, "rb").read()
    offsets = find_members(raw)
    if len(offsets) != len(MANIFEST):
        sys.exit(
            f"error: expected {len(MANIFEST)} SZDD members in {installer}, found "
            f"{len(offsets)}. This is probably a different QuickTime build than the "
            f"one this manifest was built from; fall back to running the installer."
        )

    # A win64 prefix puts 32-bit system files in syswow64; a win32 prefix in system32.
    sysdir = "syswow64" if os.path.isdir(os.path.join(drive_c, "windows", "syswow64")) else "system32"

    # Two phases on purpose. Decompress and verify EVERYTHING before writing
    # anything, so a failure midway cannot leave a half-installed QuickTime on
    # disk. That matters because callers skip this step when QTIM32.DLL exists,
    # and QTIM32.DLL is only member 9 of 27 — a partial write would look
    # complete forever while the codecs behind it were missing.
    staged = []
    for n, off in enumerate(offsets):
        end = offsets[n + 1] if n + 1 < len(offsets) else len(raw)
        dest_rel, want_size, want_md5 = MANIFEST[n]
        declared = struct.unpack("<I", raw[off + 10 : off + 14])[0]
        data = szdd_decompress(raw[off + SZDD_HEADER_LEN : end], declared)

        if len(data) != want_size:
            sys.exit(f"error: {dest_rel}: got {len(data)} bytes, expected {want_size}")
        got_md5 = hashlib.md5(data).hexdigest()
        if got_md5 != want_md5:
            sys.exit(f"error: {dest_rel}: md5 {got_md5}, expected {want_md5}")
        staged.append((dest_rel, data))

    written = 0
    for dest_rel, data in staged:
        area, name = dest_rel.split("/", 1)
        dest_dir = os.path.join(drive_c, "windows", sysdir if area == "system" else "")
        os.makedirs(dest_dir, exist_ok=True)
        with open(os.path.join(dest_dir, name), "wb") as fh:
            fh.write(data)
        written += 1

    # Windows INI, so CRLF — matches the file the real installer writes byte for byte.
    ini = os.path.join(drive_c, "windows", "QTW.INI")
    if not os.path.exists(ini):
        with open(ini, "w", newline="\r\n") as fh:
            fh.write(QTW_INI)

    print(
        f"QuickTime 2.1.2: {written} extracted files verified and installed to "
        f"windows/{sysdir}, plus QTW.INI ({written + 1} total)"
    )


if __name__ == "__main__":
    main()
