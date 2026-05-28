#!/usr/bin/env python3
"""Generate app icons: grey primary (from green artwork), green/black alternates, App Store 1024."""
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APPICON_DIR = ROOT / "Assets.xcassets" / "AppIcon.appiconset"
GREEN_BIN_SRC = ROOT / "GreenBin@3x.png"
GREY_BIN_SRC = ROOT / "GreyBin@3x.png"
GREY_PROFILE = "/System/Library/ColorSync/Profiles/Generic Gray Gamma 2.2 Profile.icc"


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


def sips_resize(src: Path, dest: Path, size: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-z", str(size), str(size), str(src), "--out", str(dest)], check=True)
    print(f"  {dest.relative_to(ROOT.parent)} ({size}x{size})")


def sips_greyscale(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-s", "format", "png", "-m", GREY_PROFILE, str(src), "--out", str(dest)],
        check=True,
    )
    print(f"  {dest.relative_to(ROOT.parent)} (greyscale from {src.name})")


def create_legacy_colored_bins() -> None:
    print("Regenerating colored alternate icon PNGs...")
    create_png(ROOT / "GreenBin-152.png", 76, 175, 80, 152)
    create_png(ROOT / "BlackBin-152.png", 30, 30, 30, 152)
    create_png(ROOT / "GreenBin@2x.png", 76, 175, 80, 120)
    create_png(ROOT / "GreenBin@3x.png", 76, 175, 80, 180)
    create_png(ROOT / "BlackBin@2x.png", 30, 30, 30, 120)
    create_png(ROOT / "BlackBin@3x.png", 30, 30, 30, 180)


def create_grey_bins_from_green() -> None:
    if not GREEN_BIN_SRC.exists():
        print(f"  Missing {GREEN_BIN_SRC.name}; run with --legacy first.")
        sys.exit(1)

    print("Deriving grey primary icon from GreenBin@3x...")
    sips_greyscale(GREEN_BIN_SRC, GREY_BIN_SRC)
    sips_resize(GREY_BIN_SRC, ROOT / "GreyBin@2x.png", 120)
    sips_resize(GREY_BIN_SRC, ROOT / "GreyBin-152.png", 152)


def create_app_store_icon_from_grey() -> None:
    """1024×1024 marketing / AppIcon — neutral grey bin (primary icon)."""
    if not GREY_BIN_SRC.exists():
        print(f"  Missing {GREY_BIN_SRC.name}; generating grey bins first.")
        create_grey_bins_from_green()

    for dest in (
        APPICON_DIR / "AppIcon-1024.png",
        ROOT.parent / "AppStore" / "app-icon-1024.png",
    ):
        sips_resize(GREY_BIN_SRC, dest, 1024)
        print(f"    -> App Store / asset catalog (grey primary)")


def main() -> None:
    if "--legacy" in sys.argv or not GREEN_BIN_SRC.exists():
        create_legacy_colored_bins()
    create_grey_bins_from_green()
    print("Generating App Store / AppIcon from grey artwork...")
    create_app_store_icon_from_grey()
    print("Done.")


if __name__ == "__main__":
    main()
