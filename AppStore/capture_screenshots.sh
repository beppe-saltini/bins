#!/bin/bash
# Capture iPhone screenshots from the booted Simulator.
# 1. Boot an iPhone 16 Pro (or change DEVICE below)
# 2. Run BinsApp in Simulator with an address configured
# 3. Run: ./AppStore/capture_screenshots.sh

set -euo pipefail
cd "$(dirname "$0")/.."
OUT="AppStore/screenshots"
mkdir -p "$OUT"

# iPhone 14 Plus = 6.5" class → 1284×2778 (matches App Store Connect "6.5\" Display" slot)
DEVICE="${DEVICE:-iPhone 14 Plus}"

if ! xcrun simctl list devices booted | grep -q Booted; then
  echo "No booted simulator. In Xcode, run BinsApp on simulator: $DEVICE"
  exit 1
fi

echo "Capturing to $OUT/ ..."
xcrun simctl io booted screenshot "$OUT/01-raw.png"
./AppStore/prepare_screenshots.sh "$OUT/01-raw.png"
echo "Upload $OUT/appstore-6.5-01-raw.png to App Store Connect → 6.5\" Display."
