#!/bin/bash
# Capture iPhone screenshots from the booted Simulator.
# 1. Boot an iPhone 16 Pro (or change DEVICE below)
# 2. Run BinsApp in Simulator with an address configured
# 3. Run: ./AppStore/capture_screenshots.sh

set -euo pipefail
cd "$(dirname "$0")/.."
OUT="AppStore/screenshots"
mkdir -p "$OUT"

DEVICE="${DEVICE:-iPhone 16 Pro}"

if ! xcrun simctl list devices booted | grep -q Booted; then
  echo "No booted simulator. Open Xcode → run BinsApp on $DEVICE first."
  exit 1
fi

echo "Capturing to $OUT/ ..."
xcrun simctl io booted screenshot "$OUT/01-main-screen.png"
echo "Saved $OUT/01-main-screen.png"
echo "Upload 6.7\" screenshots (1290×2796) in App Store Connect — resize/crop if needed."
