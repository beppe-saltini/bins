#!/usr/bin/env python3
"""Generate home-screen alternate icons and App Store / asset-catalog icons."""
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APPICON_DIR = ROOT / "Assets.xcassets" / "AppIcon.appiconset"


def create_png(path: Path, r: int, g: int, b: int, size: int) -> None:
    def chunk(ctype: bytes, data: bytes) -> bytes:
        c = ctype + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    raw = b""
    for _ in range(size):
        raw += b"\x00" + bytes([r, g, b]) * size
    idat = chunk(b"IDAT", zlib.compress(raw, 9))
    iend = chunk(b"IEND", b"")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(sig + ihdr + idat + iend)
    print(f"  {path.relative_to(ROOT.parent)} ({size}x{size})")


def main() -> None:
    import sys

    print("Generating App Store / asset-catalog icons...")
    create_png(APPICON_DIR / "AppIcon-1024.png", 76, 175, 80, 1024)
    create_png(ROOT.parent / "AppStore" / "app-icon-1024.png", 76, 175, 80, 1024)
    if "--legacy" in sys.argv:
        print("Regenerating legacy home-screen icons...")
        create_png(ROOT / "GreenBin@2x.png", 76, 175, 80, 120)
        create_png(ROOT / "GreenBin@3x.png", 76, 175, 80, 180)
        create_png(ROOT / "BlackBin@2x.png", 30, 30, 30, 120)
        create_png(ROOT / "BlackBin@3x.png", 30, 30, 30, 180)
    print("Done.")


if __name__ == "__main__":
    main()
