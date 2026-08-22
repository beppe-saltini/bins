# Deploy 1.0.3 (15) to App Store

## Done in repo

- Version **1.0.3**, build **15**
- Fix Central Bedfordshire API (council migrated to new waste collection schedule URLs)
- `AppStore/whats_new.txt` — paste into **What’s New**
- `AppStore/review_notes.txt` — for App Review

## Archive & upload (CLI)

```bash
cd /Users/beppe/Projects/bins
xcodegen generate
xcodebuild -scheme BinsApp -project BinsApp.xcodeproj \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/BinsApp.xcarchive archive \
  -allowProvisioningUpdates
xcodebuild -exportArchive \
  -archivePath build/BinsApp.xcarchive \
  -exportOptionsPlist AppStore/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates
```

## App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) → **Bins**
2. **+ Version** → **1.0.3** (skip if draft exists)
3. **What’s New** → copy from `AppStore/whats_new.txt`
4. Select build **15** when processing finishes (TestFlight tab)
5. **Review notes** → copy from `AppStore/review_notes.txt`
6. **App Privacy** — no data collected; local notifications only
7. **Submit for Review**

## URLs

- Privacy: https://beppe-saltini.github.io/bins/privacy-policy.html
- Support: https://beppe-saltini.github.io/bins/support.html

## If upload fails

- Increment build in `project.yml` (`CFBundleVersion`), run `xcodegen generate`, archive again
- Build number must be higher than any build already uploaded
