#!/usr/bin/env python3
"""Generate App Icon sets (asset catalog) and notification thumbnails."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
CACHE = ROOT / ".icon-cache"
APPICON_DIR = ROOT / "Assets.xcassets" / "AppIcon.appiconset"
BLACK_APPICON_DIR = ROOT / "Assets.xcassets" / "BlackBin.appiconset"
PAD_COLOR = "E8E8E8"
GREY_PROFILE = "/System/Library/ColorSync/Profiles/Generic Gray Gamma 2.2 Profile.icc"
ARTWORK_COMMIT = "9b94ad2"

APPICON_CONTENTS = """{
  "images" : [
    {
      "filename" : "{filename}",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""


def sips_greyscale(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-s", "format", "png", "-m", GREY_PROFILE, str(src), "--out", str(dest)],
        check=True,
    )
    print(f"  {dest.relative_to(REPO)} (greyscale)")


def sips_resize(src: Path, dest: Path, size: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-z", str(size), str(size), str(src), "--out", str(dest)], check=True)
    print(f"  {dest.relative_to(REPO)} ({size}x{size})")


def sips_homescreen_icon(src: Path, dest: Path, size: int) -> None:
    """Opaque light-grey tile so the bin shape is visible on the home screen."""
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
    print(f"  {dest.relative_to(REPO)} ({size}x{size}, padded)")


def write_appiconset(dir: Path, png_name: str) -> None:
    dir.mkdir(parents=True, exist_ok=True)
    (dir / "Contents.json").write_text(APPICON_CONTENTS.replace("{filename}", png_name))


def restore_artwork_from_git() -> tuple[Path, Path]:
    CACHE.mkdir(parents=True, exist_ok=True)
    green = CACHE / "green-source@3x.png"
    black_notify = CACHE / "black-notify-source@3x.png"
    for name, dest in (("GreenBin@3x.png", green), ("BlackBin@3x.png", black_notify)):
        result = subprocess.run(
            ["git", "show", f"{ARTWORK_COMMIT}:Resources/{name}"],
            cwd=REPO,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise SystemExit(f"Could not load Resources/{name} from git commit {ARTWORK_COMMIT}")
        dest.write_bytes(result.stdout)
        print(f"  restored {dest.relative_to(REPO)} from git")
    return green, black_notify


def main() -> None:
    if "--refresh-cache" in sys.argv or not (CACHE / "green-source@3x.png").exists():
        print("Restoring original bin artwork...")
        green_src, black_notify_src = restore_artwork_from_git()
    else:
        green_src = CACHE / "green-source@3x.png"
        black_notify_src = CACHE / "black-notify-source@3x.png"

    refuse_src = CACHE / "refuse-home@3x.png"
    print("Building refuse alternate artwork (dark grey bin)...")
    sips_greyscale(green_src, refuse_src)

    print("Asset catalog: AppIcon (green primary)...")
    write_appiconset(APPICON_DIR, "AppIcon-1024.png")
    sips_homescreen_icon(green_src, APPICON_DIR / "AppIcon-1024.png", 1024)
    sips_homescreen_icon(green_src, REPO / "AppStore" / "app-icon-1024.png", 1024)

    print("Asset catalog: BlackBin (refuse alternate)...")
    write_appiconset(BLACK_APPICON_DIR, "BlackBin-1024.png")
    sips_homescreen_icon(refuse_src, BLACK_APPICON_DIR / "BlackBin-1024.png", 1024)

    print("Notification thumbnails...")
    sips_resize(green_src, ROOT / "GreenBin-152.png", 152)
    sips_resize(black_notify_src, ROOT / "BlackBin-152.png", 152)

    print("Done.")


if __name__ == "__main__":
    main()
