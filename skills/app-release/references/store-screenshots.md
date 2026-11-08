# Store screenshots

Pipeline: **capture → brief → Claude Design → export → upload.** Every app uses the same
structure with its own brand values. Screenshots are captured from an integration test, not
from an in-app screenshot tour, so no debug code ships in the app binary.

## Repo layout per app

```
store/
  brand/            icons + feature graphic
  listing/
    listing.md      title, short + full description per locale
    aso_handoff.md  the design brief (template below)
    captures/       raw screenshots: 01-<screen>.png, 02-<screen>.png ...
    export/ios/     final 6.9" set
    export/play/    final Play set
```

## 1. Capture

Screenshots must be reproducible: the same data and the same status bar every time.

**Automatic, from the integration test fakes.** `integration_test/store_screenshots_test.dart`
pumps the app with the demo repositories and platform fakes already used in
`integration_test/`, navigates to each screen and calls `binding.takeScreenshot('01-<screen>')`
(on Android call `binding.convertFlutterSurfaceToImage()` first). Run it with `flutter drive`
and a `test_driver/integration_test.dart` whose `onScreenshot` callback writes the bytes into
`store/listing/captures/`. Run once on the 6.9" iPhone simulator and once on an Android phone
emulator.

**Clean status bar before capturing:**

```bash
# iOS simulator
xcrun simctl status_bar booted override --time 9:41 --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3

# Android emulator (demo mode)
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
# afterwards: ... -e command exit
```

**Manual only for system UI** Flutter cannot render (lock screen, native sheets, home-screen
widgets). The brief lists these as "still to take" with exact steps.

Capture rules: demo data that looks lived-in (no empty lists, no "Test 1"), realistic names,
the theme the app ships with, `debugShowCheckedModeBanner: false`, no notifications.

## 2. Brief (`aso_handoff.md`)

```markdown
# Screenshot handoff brief
Paste this into Claude Design together with the captures. Headlines are proposals until the owner signs them off.

## Context
<2–3 sentences: what the app is, for whom, the one thing that makes it different.>
Targets: iPhone 6.9" 1320 × 2868 px portrait. Play: 1080 × 1920 px (separate export).

## Set-wide visual rules
- Background: <brand color hex>, solid. No gradients, glows or light effects.
- Headlines: <font>, <color>, uppercase, centred. Line 1 = the verb, largest. Line 2 = descriptor, smaller.
- Text inside the middle 70 % of the width; headline in the top 20–25 %.
- Device: modern iPhone frame, centred, placed high, bottom running off the canvas.
- Same font, sizes, frame and background on every image: the set reads as one series.
- <app-specific, e.g. pixel art scaled by whole numbers only, never smoothed>

## Per-screenshot brief
1. <VERB LINE> / <DESCRIPTOR LINE>
   Capture: captures/01-<screen>.png | Shows: <what is visible>
   Breakout: <one UI element scaled past the phone edges, or none>
...

## Anti-patterns
No watermarks, no text beyond the two headline lines, no store chrome, no gradients, no rotated panels, no text near the edges. <claims the app must never make>
```

Headlines: 5–6 images; image 1 carries the core promise (most people only see 1–3); one benefit
per image, verb first, at most ~5 words per line; the order follows the user's first session.
Headlines are localized together with `listing.md`; the visuals stay the same.

## 3. Claude Design

Attach the brief and all captures to one canvas. Generate image 1, lock the style, then the
rest. Reuse the saved design system or the app's previous set instead of restating the style.

## 4. Export: two sets, the sizes differ

| Store | Size | Notes |
|---|---|---|
| App Store | 1320 × 2868 (6.9"), required | smaller iPhones scale from it |
| Google Play | **1080 × 1920** (9:16) | the long side may be at most 2× the short side, so **1320 × 2868 (2.17 : 1) is rejected** |

- Play: JPEG or 24-bit PNG **without alpha**, 2–8 images, max 8 MB each. Android frame or no
  frame, not an iPhone frame. Re-lay out from the same design at 9:16; never crop the iOS image.
- Check before upload (macOS): `sips -g pixelWidth -g pixelHeight -g hasAlpha store/listing/export/*/*.png`

## 5. Done means

Both export folders filled with the right sizes, headlines signed off by the owner, `listing.md`
and the screenshots in the same locales, files committed under `store/listing/export/`.
