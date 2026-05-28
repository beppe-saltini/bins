#!/bin/bash
# Prepare screenshots for App Store Connect → iPhone → 6.5" Display.
# Usage: ./AppStore/prepare_screenshots.sh ~/Desktop/screenshot.png
#
# Output: 1284 x 2778 px (portrait)

set -euo pipefail
cd "$(dirname "$0")"
OUT="screenshots"
mkdir -p "$OUT"

W=1284
H=2778

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <screenshot.png> [more...]"
  exit 1
fi

for src in "$@"; do
  [[ -f "$src" ]] || { echo "Not found: $src"; exit 1; }
  base=$(basename "$src" .png)
  dest="$OUT/appstore-6.5-${base}.png"
  tmp=$(mktemp "${TMPDIR:-/tmp}/bins-shot.XXXXXX.png")

  cp "$src" "$tmp"
  sips --resampleHeightWidthMax "$H" "$tmp" >/dev/null
  sips --padToHeightWidth "$H" "$W" "$tmp" --out "$dest" >/dev/null
  rm -f "$tmp"

  echo "Wrote $dest ($W x $H)"
done

echo ""
echo "Upload ${OUT}/appstore-6.5-*.png to App Store Connect → 6.5\" Display."
