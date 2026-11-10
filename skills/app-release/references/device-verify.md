# Verifying a change on the device

Tests prove the logic. Whether the screen looks right, the tap lands and the flow ends where
it should only shows on a device. Claude checks every change a user can see or tap on an
emulator or simulator itself, before it says done. This file is that loop. The fixed release
gate (login, purchases) is in [device-testing.md](device-testing.md).

**When:** a new or changed screen, widget, flow, navigation, deep link, permission, native
config (`ios/`, `android/`), theme or copy. **Not:** a pure domain, repository or backend
change that unit tests cover; say "no device check: no UI change" instead.

Claude never reports a device check it did not run. No device reachable → say so and list
what is left to check.

## The loop

1. **Device and build.** `bash scripts/run_e2e.sh ios --tags smoke` builds, installs, finds
   or boots the device and runs the smoke flow. A fresh clone or worktree lacks the
   git-ignored config the build needs (`.env*`, `GoogleService-Info.plist`,
   `google-services.json`, `firebase_options.dart`); copy them from the main checkout first,
   never commit them. After the first build, use `--no-build`
   until Dart or native code changes again. Android is the release APK (what ships), iOS a
   debug simulator build.
2. **Reach the screen** with a scratch flow in `build/e2e/scratch.yaml` (git-ignored with
   `build/`). Write the steps the user takes, ending in a wait for the changed screen:

   ```yaml
   appId: <application id>
   ---
   - launchApp
   - extendedWaitUntil:
       visible:
         id: "home.root"
       timeout: 30000
   - tapOn:
       id: "nav.profile"
   - extendedWaitUntil:
       visible:
         id: "profile.root"
       timeout: 10000
   ```

   `bash scripts/run_e2e.sh ios --no-build build/e2e/scratch.yaml`
3. **Look at it.** Take a screenshot and open it with the Read tool:

   ```bash
   xcrun simctl io booted screenshot "$PWD/build/e2e/shot.png"   # iOS: absolute path
   adb exec-out screencap -p > build/e2e/shot.png                 # Android
   sips -Z 900 build/e2e/shot.png --out build/e2e/shot.png        # smaller image to read
   ```

   `simctl` resolves a relative path in its own directory and fails with "The folder
   doesn't exist".

   Check what the change promised: layout, text, empty and error state, nothing cut off, the
   keyboard not covering the button. Also dark mode or a large font when the change touches
   theme or text.
4. **Find selectors** for a screen you do not know: dump the tree to a file and search it.
   Do not read the whole dump into context; it is large.

   ```bash
   maestro --device <id> hierarchy > build/e2e/tree.json
   grep -oE '"(resource-id|identifier|accessibilityText|text)" *: *"[^"]+"' build/e2e/tree.json | sort -u
   ```

   A control without an id gets `Semantics(identifier: '<area>.<name>')` in the same change.
5. **Keep or delete the flow.** A transition that broke before, or a core path (auth,
   navigation, deep link, purchase), moves into `e2e/` with ids and a tag. Everything else is
   deleted.
6. **Report** in the PR test plan: device and OS (`iPhone 17 Pro, iOS 26.4`;
   `Pixel 8, API 35`), the flows that ran with their result, the screens checked by
   screenshot. Screenshots stay out of git.

Step-by-step driving with the Maestro MCP server (`claude mcp add maestro -- maestro mcp`)
works for exploring an unknown screen, but every tap is a round trip with a screen read. A
scratch flow is cheaper as soon as the path is known.

## Which flows for which change

Every flow in `e2e/` carries `tags:`. Run the tags of the change, all flows before a release.

| Change touches | Tags |
|---|---|
| anything visible | `smoke` (launch → home ready; every app has `e2e/smoke.yaml`) |
| auth, onboarding, guest, account | `auth` |
| router, deep links, `ios/` / `android/` config | `router`, `auth` |
| paywall, purchases, entitlement webhook | `purchase` |
| release | all: `bash scripts/run_e2e.sh <platform>` on both platforms |

Platform-specific code (native config, a platform check in Dart, sheets that differ) runs on
both platforms; everything else on one is enough for a feature branch.

## Flow rules that came from failures

- **iOS keeps the keychain across `clearState`.** A session can survive a reinstall. Start
  auth flows with a conditional sign-out (or sign-in) instead of assuming a fresh state:

  ```yaml
  - runFlow:
      when:
        visible:
          id: "home.root"
      file: common/sign_out.yaml
  ```

- **Wait for ready, never tap right after launch.** The first screen waits on a cold start
  and the first fetch; on CI emulators that is up to 90 s. `extendedWaitUntil` on the screen's
  root id with a generous timeout, then tap. No fixed sleeps.
- **`hideKeyboard` is not neutral.** On some screens it submits the form, on others it fails.
  Tap the next field or the submit button directly instead.
- **Fresh-install interstitials** (welcome sheet, notification or tracking prompt) appear
  only on some runs. Dismiss them with a conditional `runFlow` by id; system dialogs by their
  text ("Allow", "Don't Allow").
- **Custom-scheme links on iOS** first show an "Open" prompt:
  `runFlow: {when: {platform: iOS, visible: "Open"}, commands: [{tapOn: "Open"}]}`.
- **Deep links twice: cold and warm.** Cold start = `stopApp`, then `openLink`; warm = the
  app running in the background, then `openLink`. They take different code paths and break
  separately.
- **No coordinate taps** (`point: "85%,91%"`): they hit something else on another screen
  size or with a banner. An icon-only tab gets an id instead.
- **Rows below the fold need a scroll.** `extendedWaitUntil` does not scroll; a menu row that
  fits on a tall simulator is off-screen on a shorter phone. Use
  `scrollUntilVisible: {element: {id: "profile.subscription"}, direction: DOWN}` before
  tapping anything in a long list.
- **Text selectors only for native views** (account picker, system dialogs, store sheets).
  Everything Flutter renders is matched by id.
- **A fresh install proves less.** On a new simulator the app starts signed out, so a smoke
  flow ends on the welcome screen and never touches the tabs. Say which state the run
  covered; signed-in screens need the test user from `.env.e2e`.
- **A wedged emulator hangs Maestro**, on iOS runs too: `adb devices` still says `device`
  while `adb shell` never returns. `run_e2e.sh` checks this and stops; free or restart the
  emulator. If another session is using it, do not kill it.
