# Platform facts with a date

Everything here changes under us. **Verified on 2026-11-10.** When this date is older than
90 days, re-check every row against the vendor page in the last column before relying on it,
then change the date. The skills link here instead of repeating a value.

| Fact | Value | Check at |
|---|---|---|
| Play target API | API 36 for new apps and updates since 2026-08-31 | Play Console, target API requirements |
| Android 16 / API 36 | ignores orientation and resize locks on screens 600 dp and wider; the opt-out ends with API 37 | Android developers, behavior changes |
| App Store toolchain | uploads built with the Xcode 26 SDK required since 2026-04-28 | App Store Connect, upcoming requirements |
| CocoaPods trunk | read-only from 2026-12-02: plugins that still resolve through trunk need a Swift Package Manager path | CocoaPods blog |
| Supabase Data API exposure | new tables are no longer exposed automatically (new projects since 2026-05-30; existing projects announced for 2026-10-30, unconfirmed) | Supabase changelog |
| Supabase legacy `anon` / `service_role` keys | deprecated, end of 2026 | Supabase docs, API keys |
| Apple token revocation | account deletion must revoke the Sign in with Apple token (TN3194) | Apple developer technical notes |
| Play Store screenshots | 1080 × 1920, 2–8 images, no alpha, max 8 MB each | Play Console help |
| App Store screenshots | 1320 × 2868 (6.9") required | App Store Connect help |
| Android emulator image | `system-images;android-35;google_apis_playstore;arm64-v8a` (with Play Store: Google sign-in needs Play services) | `sdkmanager --list` |
| `google_sign_in` | 7.x: `initialize(nonce:)` available from 7.2.0 | pub.dev changelog |
| RevenueCat `test_` key | fatal error in a release build | RevenueCat docs, Test Store |

Link rows from the skills with `[platform-facts]` with a relative link; never copy the value.
