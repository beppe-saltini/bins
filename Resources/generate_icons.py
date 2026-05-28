#!/usr/bin/env python3
"""App Store 1024 only. Home-screen icons are Resources/GreenBin@*.png and BlackBin@*.png (checked into git)."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
APPICON_DIR = ROOT / "Assets.xcassets" / "AppIcon.appiconset"
GREEN_SRC = ROOT / "GreenBin@3x.png"

APPICON_CONTENTS = """{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
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


def sips_resize(src: Path, dest: Path, size: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-z", str(size), str(size), str(src), "--out", str(dest)], check=True)
    print(f"  {dest.relative_to(REPO)} ({size}x{size})")


def main() -> None:
    if not GREEN_SRC.exists():
        print(f"Missing {GREEN_SRC.name}. Restore from git commit 9b94ad2 first.")
        sys.exit(1)

    APPICON_DIR.mkdir(parents=True, exist_ok=True)
    (APPICON_DIR / "Contents.json").write_text(APPICON_CONTENTS)
    print("App Store / catalog 1024 (from GreenBin@3x)...")
    sips_resize(GREEN_SRC, APPICON_DIR / "AppIcon-1024.png", 1024)
    sips_resize(GREEN_SRC, REPO / "AppStore" / "app-icon-1024.png", 1024)
    print("Done. Do not run --legacy; home icons are the loose PNG files.")


if __name__ == "__main__":
    main()
