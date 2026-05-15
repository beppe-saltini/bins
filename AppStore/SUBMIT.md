# App Store submission checklist

## 1. Host privacy policy & support (required URLs)

Upload the `docs/` folder to GitHub Pages (or any static host):

1. Create a repo (e.g. `bins-app-pages`) or use this repo’s **Settings → Pages**.
2. Set source to branch `main`, folder `/docs`.
3. Your URLs will be:
   - **Privacy Policy:** `https://<username>.github.io/<repo>/privacy-policy.html`
   - **Support URL:** `https://<username>.github.io/<repo>/support.html`

Use those exact URLs in App Store Connect.

Update the support email in `docs/support.html` if needed.

## 2. App Store Connect metadata

Copy from this folder:

| Field | File |
|-------|------|
| Description | `description.txt` |
| Keywords | `keywords.txt` |
| Subtitle | `subtitle.txt` |
| Promotional text | `promotional_text.txt` |
| Review notes | `review_notes.txt` |

- **Category:** Utilities
- **Price:** Free
- **Age rating:** 4+ (no restricted content)
- **Copyright:** e.g. `2026 Your Name`

## 3. Icons & screenshots

| Asset | Location |
|-------|----------|
| 1024×1024 App Store icon | `AppStore/app-icon-1024.png` (upload in App Store Connect) |
| In-app icon | `Resources/Assets.xcassets/AppIcon.appiconset/` (built into the app) |

**Screenshots** (required — take on iPhone or Simulator):

1. Run the app with an address configured.
2. Capture the main green/black bin screen.
3. Optional: Settings postcode screen, widget on home screen.
4. Upload **6.7"** iPhone screenshots in App Store Connect (1290×2796 px).

```bash
# Example: Simulator screenshot (after opening app)
xcrun simctl io booted screenshot AppStore/screenshot-main.png
```

## 4. Archive & upload (Xcode)

1. Scheme **BinsApp**, destination **Any iOS Device (arm64)**.
2. **Product → Archive**.
3. **Distribute App → App Store Connect → Upload**.
4. Wait for processing in App Store Connect → **TestFlight** or **App Store** tab.

## 5. App privacy questionnaire (Connect)

- **Data collection:** No — data not collected by you (stored on device only; council site contacted directly by app).
- **Encryption:** Standard HTTPS only (`ITSAppUsesNonExemptEncryption` is false in the app).

## 6. Regenerate icons (optional)

```bash
python3 Resources/generate_icons.py
xcodegen generate
```
