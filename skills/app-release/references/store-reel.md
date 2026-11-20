# Store reel (motion version of the screenshots)

A 30–45 s portrait video built from the store screenshot set: one slide per screenshot, each
with its own motion. It is for social posts and a promo video (Play takes a YouTube link). It
is **not** an App Store app preview: Apple's previews have their own length, size, audio and
footage rules, so build those separately from screen recordings only. Build the reel after
the screenshots are signed off; it reuses their layouts and headlines.

Pipeline: **record the app → one HTML timeline per slide → render frames → compose.**
Templates: [templates/store/reel/](../../../templates/store/reel/) (`anim.js` timeline helpers, `render.js` frame renderer,
`compose.py` background, transitions and final file).

## Where the files go

Recordings, frames and renders are large (one slide is ~250 JPEGs at 1320 × 2868). Put the
work folder on a disk with room from the first step, not in the repo and not in a cloud
folder. `simctl recordVideo` cannot write to an external volume (SimRenderServer error 2):
record to the internal disk, then move the file. Name the full output path when you hand it over.

## 1. Record the app

An integration test in reel mode (`integration_test/store_reel_test.dart`, next to the
screenshot test, same demo data and fakes) plays the flow in real time while the simulator
records:

```bash
xcrun simctl status_bar <udid> clear
xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl io <udid> screenshot /tmp/check.png   # look at it: "9:41", not "09:41"
xcrun simctl io <udid> recordVideo --codec=h264 --force raw.mov &   # start before flutter drive
flutter drive --driver test_driver/<driver>.dart --target integration_test/store_reel_test.dart -d <udid>
kill -INT %1
```

- The test prints `REEL <segment> <epoch ms>` at the start and end of each segment.
- **"09:41" in the status bar:** set the simulator (not the Mac) to a 12-hour region:
  `xcrun simctl spawn <udid> defaults write -g AppleLocale en_US`,
  `xcrun simctl spawn <udid> defaults write -g AppleICUForce24HourTime -bool false`, then
  `xcrun simctl shutdown <udid> && xcrun simctl boot <udid>`. Run `clear` before `override`,
  since after a reboot the override can come back in 24-hour form.
- **Finding the segments in the video:** the recording has a variable frame rate and an
  unknown start offset. Take the marks relative to the last one, then find one visible event
  (controls appearing, a sheet opening) by grabbing single frames with `ffmpeg -ss <t>`. A
  1 fps contact sheet repeats static frames and gives the wrong times.
- **Keep the UI on screen:** chrome that auto-hides has to be revealed again every ~500 ms
  during a segment.
- **Progress must visibly move:** give the demo track a short fake duration (~45 s) so a
  progress bar or waveform advances about one step per second. Push it *after* the call that
  starts playback: starting a track resets the duration to the track's own. Check a crop of
  the progress bar, not just the clock.
- **Taps leave a marker:** `tester.tap` in a live test paints a crosshair into 1–2 recorded
  frames. Find those frames by colour and replace each with the next clean frame, or call the
  widget's callback instead of tapping.
- **Fast system animations** (a modal sheet opening) last 1–2 recorded frames. Record the
  sheet at rest and animate it in the slide instead.
- A language switch that rebuilds the app shell needs a wait (~14 s) before the first segment.

Cut each segment to frames: `ffmpeg -ss <start> -t <len> -i raw.mov -vf fps=30,scale=1320:2868 -q:v 3 <seg>/%04d.jpg`.

## 2. One timeline per slide

Each slide is an HTML page at 1320 × 2868 with the screenshot's layout and a
`render(t)` function that sets every element from `t` alone (no CSS animations, no timers),
so any frame can be rendered in any order. `frame(img, dir, t, {count, offset})` swaps the
recorded app frames into the phone screen; `count` (the last clean frame) is required.

**What moves.** Each slide's motion matches its own headline:
- the headline rises in word by word, the second line types in
- the phone enters
- the recorded app content runs
- the decorative pixels move (notes rise, leaves fall, lights flicker)
- the claim on that slide is highlighted

A static slide with a slow zoom was rejected as "too simple".

**Pacing.** The owner found the first cut "too hectic". These values were accepted. They are
for the rendered marketing video only; in-app motion follows lean-flutter-ui.

| What | Value |
|---|---|
| Slide length | 6–8.5 s |
| Entrances (phone, headline, bubble) | 0.9–1.6 s, `outCubic`, no overshoot or back easing |
| Headline words | ~0.22 s apart |
| Typed line | ~0.07 s per letter |
| Particles | cycles of 3.4–5 s |
| Light flicker | below 3 Hz, low contrast |
| Transition between slides | 0.7 s `xfade=smoothleft` |

**Show only what the slide claims.**
- Start the recorded segment where the claim is already on screen (`offset`), not at the
  navigation leading there.
- Use one interaction at most. Tapping filter chips made the chip row jump and was called
  "chaos".

**Highlighting without colour.**
- An accent ring or bar was rejected ("no orange").
- What was accepted: lift the item. Take a copy of the row from the same frame, scale it by
  1.04, brightness 1.1, give it a soft dark shadow, and lift one row after another.

**Creatures and sprites.**
- Reuse the app's own animation sheets (one row of frames). Use them as a CSS background,
  stepped one frame at a time, scaled by a whole number with `image-rendering: pixelated`.
- Play them once, slowly (~5 fps), not in a loop.
- Never hand-animate a creature.
- Sleep "z" marks:
  - Use them at most on one creature, small and short.
  - They come from the side the head is on.
  - They stay clear of the other decor.

**Keep decor clear.** Falling or floating decor fades out at least ~100 px before a creature,
the headline or the phone. Check the closest approach over all frames, not a few stills.

**Text.** Pixel fonts: `font-variant-ligatures: none` (see store-screenshots.md).

**Editing generated HTML.**
- When adding an `id` to an element, put it before `style="`. Inserting text into the middle
  of a style attribute silently drops the rest of it.

## 3. Render and check

```bash
CHROME=<headless shell> node render.js "$PWD/s1.html" out/s1 7.0
ffmpeg -framerate 30 -i out/s1/%04d.jpg -c:v libx264 -crf 18 -pix_fmt yuv420p out/s1.mp4
```

Check each slide before composing, since one bad frame is easy to miss at full speed:
- a contact strip of 4–5 times
- a crop of the progress bar
- the moving edges, measured frame by frame:
  - **A jump** (a sheet handle or phone edge changing position mid-slide) usually means the
    segment ran out of frames.
  - Clamp `count` to the last clean frame. The last frame of a cut can already show the next
    transition.

## 4. Compose

`compose.py <bg.png> <out.mp4> s1.mp4 … s6.mp4`. Each slide is scaled to 884 × 1920 and
centred on a 1080 × 1920 background. The background is the slides' own pattern, with its grid
aligned so the side bands are invisible. The slides are joined with 0.7 s transitions, and
the last frame is held for 1 s.

## 5. Done means

- The owner has watched it on a phone.
- The headlines match the signed-off screenshots.
- No tap markers or status bar errors remain.
- The final file and the slide sources are kept on the work disk.
- The reel is not committed to the app repo; its path is recorded in the app's store notes.
