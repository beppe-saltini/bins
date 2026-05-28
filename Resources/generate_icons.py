#!/usr/bin/env python3
"""Generate app icons: grey primary, green/black alternates, notification thumbnails."""
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CACHE = ROOT / ".icon-cache"
APPICON_DIR = ROOT / "Assets.xcassets" / "AppIcon.appiconset"
GREEN_BUNDLE = ROOT / "GreenBin@3x.png"
BLACK_BUNDLE = ROOT / "BlackBin@3x.png"
GREY_BIN_SRC = ROOT / "GreyBin@3x.png"
GREY_PROFILE = "/System/Library/ColorSync/Profiles/Generic Gray Gamma 2.2 Profile.icc"
PAD_COLOR = "E8E8E8"  # light grey tile so black bin is visible on the home screen

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
    print(f"  {dest.relative_to(ROOT.parent)} ({size}x{size})")


def sips_greyscale(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-s", "format", "png", "-m", GREY_PROFILE, str(src), "--out", str(dest)],
        check=True,
    )
    print(f"  {dest.relative_to(ROOT.parent)} (greyscale)")


def sips_homescreen_icon(src: Path, dest: Path, size: int) -> None:
    """Shrink artwork slightly and pad to a light square — readable on the home screen."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    inner = max(1, int(size * 0.86))
    subprocess.run(["sips", "-z", str(inner), str(inner), str(src), "--out", str(dest)], check=True)
    subprocess.run(
        [
            "sips",
            "--padToHeightWidth",
            str(size),
            str(size),
            "--padColor",
            PAD_COLOR,
            str(dest),
            "--out",
            str(dest),
        ],
        check=True,
    )
    print(f"  {dest.relative_to(ROOT.parent)} ({size}x{size}, padded)")


def is_real_artwork(path: Path) -> bool:
    return path.exists() and path.stat().st_size >= MIN_ARTWORK_BYTES


def refresh_icon_cache() -> tuple[Path, Path]:
    CACHE.mkdir(parents=True, exist_ok=True)
    green = CACHE / "green-source@3x.png"
    black = CACHE / "black-source@3x.png"

    if is_real_artwork(GREEN_BUNDLE):
        shutil.copy2(GREEN_BUNDLE, green)
    if is_real_artwork(BLACK_BUNDLE):
        shutil.copy2(BLACK_BUNDLE, black)

    if not is_real_artwork(green):
        print("ERROR: Missing GreenBin@3x artwork. Restore from git or add PNG.")
        sys.exit(1)
    if not is_real_artwork(black):
        print("ERROR: Missing BlackBin@3x artwork.")
        sys.exit(1)

    return green, black


def create_solid_placeholders() -> None:
    print("Creating solid placeholders for missing files only...")
    if not is_real_artwork(GREEN_BUNDLE):
        create_png(ROOT / "GreenBin@2x.png", 76, 175, 80, 120)
        create_png(GREEN_BUNDLE, 76, 175, 80, 180)
    if not is_real_artwork(BLACK_BUNDLE):
        create_png(ROOT / "BlackBin@2x.png", 30, 30, 30, 120)
        create_png(BLACK_BUNDLE, 30, 30, 30, 180)


def main() -> None:
    if "--solid-placeholders" in sys.argv:
        create_solid_placeholders()

    if "--refresh-cache" in sys.argv or not (CACHE / "green-source@3x.png").exists():
        print("Refreshing icon source cache...")
        green_src, black_src = refresh_icon_cache()
    else:
        green_src = CACHE / "green-source@3x.png"
        black_src = CACHE / "black-source@3x.png"
        if not green_src.exists():
            green_src, black_src = refresh_icon_cache()

    print("Building home-screen icons (light grey tile)...")
    sips_homescreen_icon(green_src, GREEN_BUNDLE, 180)
    sips_homescreen_icon(green_src, ROOT / "GreenBin@2x.png", 120)
    sips_homescreen_icon(black_src, BLACK_BUNDLE, 180)
    sips_homescreen_icon(black_src, ROOT / "BlackBin@2x.png", 120)

    print("Deriving grey primary from green artwork...")
    grey_raw = CACHE / "grey-raw@3x.png"
    sips_greyscale(green_src, grey_raw)
    sips_homescreen_icon(grey_raw, GREY_BIN_SRC, 180)
    sips_homescreen_icon(grey_raw, ROOT / "GreyBin@2x.png", 120)

    print("Notification thumbnails (uncropped colour)...")
    sips_resize(green_src, ROOT / "GreenBin-152.png", 152)
    sips_resize(black_src, ROOT / "BlackBin-152.png", 152)
    sips_resize(grey_raw, ROOT / "GreyBin-152.png", 152)

    print("App Store / asset catalog 1024...")
    for dest in (
        APPICON_DIR / "AppIcon-1024.png",
        ROOT.parent / "AppStore" / "app-icon-1024.png",
    ):
        sips_homescreen_icon(grey_raw, dest, 1024)

    print("Done.")


if __name__ == "__main__":
    main()
