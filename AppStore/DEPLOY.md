# Deploy 1.0.2 (13) to App Store

## Done in repo

- Version **1.0.2**, build **13**
- Production icons + simple reminders (`0faf9eb`)
- `AppStore/whats_new.txt` — paste into **What’s New**
- `AppStore/description.txt` — updated with reminders line
- `AppStore/review_notes.txt` — for App Review

## Your steps in Xcode (≈10 min)

1. Open `BinsApp.xcodeproj`
2. Target **BinsApp** → **Signing & Capabilities** → Team **MCZH73T4Z2**, **Automatically manage signing** on
3. Same for **BinsWidget** target
4. Scheme **BinsApp** → destination **Any iOS Device (arm64)**
5. **Product → Archive**
6. **Distribute App → App Store Connect → Upload**

## App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) → **Bins**
2. **+ Version** → **1.0.2** (skip if draft exists)
3. **What’s New** → copy from `AppStore/whats_new.txt`
4. Select build **13** when processing finishes (TestFlight tab)
5. **Review notes** → copy from `AppStore/review_notes.txt`
6. **App Privacy** — no data collected; local notifications only
7. **Submit for Review**

## URLs

- Privacy: https://beppe-saltini.github.io/bins/privacy-policy.html
- Support: https://beppe-saltini.github.io/bins/support.html

## If upload fails

- Increment build in `project.yml` (`CFBundleVersion: "14"`), run `xcodegen generate`, archive again
- Build number must be higher than any build already uploaded
