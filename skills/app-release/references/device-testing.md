# Device testing: login and auth flows

Login breaks inside native sheets and in platform configuration, where widget tests cannot
see. This file says how to test it with as little manual work as possible. Claude follows it
before every store upload and whenever a change touches auth, the router or deep links.

Three layers, cheapest first:

| Layer | What | Who |
|---|---|---|
| 1. Config check | entitlements, URL schemes, deep-link flags, SHA-1 fingerprints | `scripts/check_login_config.sh`, in CI and before release |
| 2. Maestro flows | the app's real UI around login: email, Google (Android), guest conversion, sign-out and deletion landing | Claude on the Mac (emulator + simulator); the fast flows also in CI |
| 3. Manual remainder | Apple and Google sign-in on a real iPhone, release build | the owner, ~2 minutes, result in the release PR |

Claude never reports layer 2 or 3 as passed unless it actually ran or saw the result. If no
emulator or simulator is reachable, it says so and lists what is left to run.

## 1. Config check

```bash
bash scripts/check_login_config.sh
```

[`../scripts/check_login_config.sh`](../scripts/check_login_config.sh) checks only what the
app uses: engine deep linking off (with `app_links`), the Apple sign-in capability in every
entitlements file, the reversed Google client ID as URL scheme, and the debug and upload key
SHA-1 against `android/google-sha1.txt`. That file lists the fingerprints registered in Google
Cloud (debug, upload, Play App Signing), one per line; keep it in sync with the console. A
missing SHA-1 is the classic "works in debug, fails in release".

## 2. Maestro flows

### Mac setup (once)

```bash
brew install openjdk@17
curl -Ls "https://get.maestro.mobile.dev" | bash

# Android emulator WITH Play Store: Google sign-in needs Google Play services
sdkmanager "system-images;android-35;google_apis_playstore;arm64-v8a"
avdmanager create avd -n e2e -d pixel_8 -k "system-images;android-35;google_apis_playstore;arm64-v8a"
emulator -avd e2e &
```

Then by hand, once:
1. Sign the Google test account in on the emulator (Settings → Accounts). Use a dedicated
   account without 2FA prompts. Save the state: `adb emu avd snapshot save logged-in`. Later
   runs start with `emulator -avd e2e -snapshot logged-in`, and the Google sheet is only an
   account picker that a flow can tap.
2. Install an iOS simulator in Xcode (the newest iPhone).
3. Create the test users in Supabase (dev and prod): one email/password user, and the Google
   test account once signed in.
4. Put the credentials in `.env.e2e` (git-ignored): `E2E_EMAIL`, `E2E_PASSWORD`,
   `E2E_GOOGLE_ACCOUNT`.

### Builds

- Android: `flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk`.
  The flows run against what ships.
- iOS simulator: `flutter build ios --simulator --debug`, then
  `xcrun simctl install booted build/ios/iphonesimulator/Runner.app`. Release builds do not run
  on a simulator; that is why layer 3 exists.

### Flows

Flows live in `e2e/`, one file per transition. The standard set for an app with login:

| Flow | Checks |
|---|---|
| `auth_email_login.yaml` | email sign-in lands on the home screen |
| `auth_google_login.yaml` (Android) | the Google account picker → home screen |
| `auth_sign_out.yaml` | sign-out lands on the welcome screen, not inside onboarding |
| `auth_guest_to_new.yaml` | guest → new account advances on the first try |
| `auth_guest_to_existing.yaml` | guest → existing account offers sign-in and then shows that account's data |
| `auth_delete_account.yaml` (dev only) | deletion lands on the welcome screen |

Selectors are Semantics identifiers, never localized text: every control a flow taps gets
`Semantics(identifier: 'auth.google', child: ...)` (pattern `<area>.<name>`), and the flow
uses `id: "auth.google"`. Native views (the Google account picker) are matched by their text.

```yaml
# e2e/auth_email_login.yaml
appId: <application id>
---
- launchApp:
    clearState: true
- tapOn:
    id: "welcome.signIn"
- tapOn:
    id: "auth.email"
- inputText: ${E2E_EMAIL}
- tapOn:
    id: "auth.password"
- inputText: ${E2E_PASSWORD}
- tapOn:
    id: "auth.submit"
- assertVisible:
    id: "home.root"
```

```yaml
# e2e/auth_google_login.yaml (Android, emulator started from the logged-in snapshot)
appId: <application id>
---
- launchApp:
    clearState: true
- tapOn:
    id: "auth.google"
- tapOn: ${E2E_GOOGLE_ACCOUNT}      # system account picker, matched by the email shown
- assertVisible:
    id: "home.root"
```

### Run and read the result

```bash
set -a; source .env.e2e; set +a
maestro --device <id> test e2e/ --format junit --output build/e2e-report.xml \
  -e E2E_EMAIL="$E2E_EMAIL" -e E2E_PASSWORD="$E2E_PASSWORD" -e E2E_GOOGLE_ACCOUNT="$E2E_GOOGLE_ACCOUNT"
```

Device ids: `adb devices` (Android), `xcrun simctl list devices booted` (iOS). Run once per
platform. Claude reads `build/e2e-report.xml`, and for every failure the screenshot Maestro
saves under `~/.maestro/tests/<timestamp>/`, then reports only what failed, with the flow, the
step and what the screen showed.

### CI (optional)

The email, guest and sign-out flows can run in GitHub Actions on an Android emulator
(`reactivecircus/android-emulator-runner`) against a dev build. Keep Google sign-in out of CI:
fresh emulators signing in from datacenter IPs trigger Google's verification prompts.

## 3. Manual remainder (release build, real iPhone)

- [ ] Sign in with Apple from a logged-out state
- [ ] Sign in with Google from a logged-out state
- [ ] Record device, iOS version and result in the release PR
