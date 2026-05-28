#!/usr/bin/env python3
"""Generate app icons: grey primary, green/black alternates (from bin artwork), notification sizes."""
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APPICON_DIR = ROOT / "Assets.xcassets" / "AppIcon.appiconset"
GREEN_BIN_SRC = ROOT / "GreenBin@3x.png"
BLACK_BIN_SRC = ROOT / "BlackBin@3x.png"
GREY_BIN_SRC = ROOT / "GreyBin@3x.png"
GREY_PROFILE = "/System/Library/ColorSync/Profiles/Generic Gray Gamma 2.2 Profile.icc"

# Real bin PNGs are much larger than solid-colour placeholders (~300 bytes).
MIN_ARTWORK_BYTES = 2000


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
    print(f"  {path.relative_to(ROOT.parent)} ({size}x{size}, solid placeholder)")


def sips_resize(src: Path, dest: Path, size: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-z", str(size), str(size), str(src), "--out", str(dest)], check=True)
    print(f"  {dest.relative_to(ROOT.parent)} ({size}x{size}, from {src.name})")


def sips_greyscale(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-s", "format", "png", "-m", GREY_PROFILE, str(src), "--out", str(dest)],
        check=True,
    )
    print(f"  {dest.relative_to(ROOT.parent)} (greyscale from {src.name})")


def is_real_artwork(path: Path) -> bool:
    return path.exists() and path.stat().st_size >= MIN_ARTWORK_BYTES


def create_solid_placeholders() -> None:
    """Only for missing artwork — never overwrites real bin graphics."""
    print("Creating solid placeholders for missing files only...")
    if not is_real_artwork(GREEN_BIN_SRC):
        create_png(ROOT / "GreenBin@2x.png", 76, 175, 80, 120)
        create_png(GREEN_BIN_SRC, 76, 175, 80, 180)
    if not is_real_artwork(BLACK_BIN_SRC):
        create_png(ROOT / "BlackBin@2x.png", 30, 30, 30, 120)
        create_png(BLACK_BIN_SRC, 30, 30, 30, 180)


def resize_notification_assets() -> None:
    if is_real_artwork(GREEN_BIN_SRC):
        sips_resize(GREEN_BIN_SRC, ROOT / "GreenBin-152.png", 152)
    if is_real_artwork(BLACK_BIN_SRC):
        sips_resize(BLACK_BIN_SRC, ROOT / "BlackBin-152.png", 152)


def create_grey_bins_from_green() -> None:
    if not is_real_artwork(GREEN_BIN_SRC):
        print(f"  ERROR: {GREEN_BIN_SRC.name} missing or placeholder. Restore bin artwork first.")
        sys.exit(1)

    print("Deriving grey primary icon from GreenBin@3x...")
    sips_greyscale(GREEN_BIN_SRC, GREY_BIN_SRC)
    sips_resize(GREY_BIN_SRC, ROOT / "GreyBin@2x.png", 120)
    sips_resize(GREY_BIN_SRC, ROOT / "GreyBin-152.png", 152)


def create_app_store_icon_from_grey() -> None:
    if not GREY_BIN_SRC.exists():
        create_grey_bins_from_green()

    print("Generating App Store / AppIcon from grey artwork...")
    for dest in (
        APPICON_DIR / "AppIcon-1024.png",
        ROOT.parent / "AppStore" / "app-icon-1024.png",
    ):
        sips_resize(GREY_BIN_SRC, dest, 1024)


def main() -> None:
    if "--solid-placeholders" in sys.argv:
        create_solid_placeholders()
    create_grey_bins_from_green()
    resize_notification_assets()
    create_app_store_icon_from_grey()
    print("Done.")


if __name__ == "__main__":
    main()
