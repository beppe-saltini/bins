#!/bin/bash
# Prepare screenshot for App Store Connect → iPad → 13" Display.
# Usage: ./AppStore/prepare_ipad_screenshot.sh ~/Desktop/screenshot.png
#
# Output: 2048 x 2732 px (portrait) — accepted for 13-inch iPad slot.

set -euo pipefail
cd "$(dirname "$0")"
OUT="screenshots"
mkdir -p "$OUT"

W=2048
H=2732

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <screenshot.png>"
  exit 1
fi

for src in "$@"; do
  [[ -f "$src" ]] || { echo "Not found: $src"; exit 1; }
  base=$(basename "$src" .png)
  dest="$OUT/appstore-ipad-13-${base}.png"
  tmp=$(mktemp "${TMPDIR:-/tmp}/bins-ipad.XXXXXX.png")
  cp "$src" "$tmp"
  sips --resampleHeightWidthMax "$H" "$tmp" >/dev/null
  sips --padToHeightWidth "$H" "$W" "$tmp" --out "$dest" >/dev/null
  rm -f "$tmp"
  echo "Wrote $dest ($W x $H)"
done

echo "Upload to App Store Connect → iPad → 13\" Display."
