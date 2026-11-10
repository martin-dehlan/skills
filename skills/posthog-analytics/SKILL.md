---
name: posthog-analytics
description: Product analytics and error tracking with PostHog in Flutter apps - setup, the analytics service, identify and reset around auth, event and property naming, privacy (ids only, scrubbing, opt-out, session replay masking), error tracking, internal and store-test traffic, reading funnels and querying with HogQL. Use when adding or changing events, touching the analytics service, auth identity, consent, or when asked what the numbers say.
---

# PostHog analytics

Every rule comes from code that shipped or from a dashboard that lied; the short reasons say
which. The repo's CLAUDE.md wins and names the concrete service class, events file and
dashboards.

## Setup

- EU cloud: `POSTHOG_HOST=https://eu.i.posthog.com`. The project key (`phc_…`) is
  publishable and goes in the bundled `.env`; the personal API key (`phx_…`) used for
  queries is a secret and goes in `.env.tools` only.
- Configure from Dart, once, in `main()` before `runApp`. On Android set
  `com.posthog.posthog.AUTO_INIT=false` in the manifest, or the native SDK starts on its own
  with no key.
- No key → a no-op service, never a crash. Tests and forks run without analytics.

## The service

One `AnalyticsService` interface, a PostHog implementation and a `NoopAnalyticsService`,
provided through Riverpod and overridden in `main()` with the initialised instance.

- **Sends never throw.** Wrap every SDK call in try/catch and drop the event. Analytics
  runs inside sign-in and purchase flows; a failed send must not fail them.
- Fire and forget: `unawaited(analytics.capture(...))`. Never `await` analytics on a path
  the user is waiting on.
- Event names live in one constants class (`AnalyticsEvents`), so the dashboard, the
  funnel doc and the code agree. A renamed event breaks every saved insight silently;
  add a new name and keep the old one in the doc's history instead.
- Feature code calls named methods or `capture(AnalyticsEvents.x, {...})`, never `Posthog()`
  directly.

## Identity

- Distinct id = Supabase `auth.users.id`. Nothing else identifies a person.
- Identify in two places: once at boot for a user who is already signed in (an auth
  listener only fires on *changes*, so a returning user is otherwise never identified),
  and on every auth change.
- A guest converting keeps the same uid. Treat the anonymous → real flip as an identity
  change and identify again, or `is_guest: true` sticks to the person and the conversion
  funnel reads zero.
- `reset()` on sign-out and account deletion, never on app start.
- `reset()` also clears super properties: register them again right after (see below).

## Internal and store traffic

- Register a `build_mode` super property (`debug` / `profile` / `release`) after `setup()`
  and after every `reset()`. Debug builds ship the same key; before this existed internal
  devices made up nearly half of one funnel step. Product dashboards filter
  `build_mode = release`.
- Store review devices look like real users. See
  [funnels and queries](references/funnels-and-queries.md#store-test-devices) before
  reading install, login or funnel numbers around a release.

## Events and properties

- `snake_case`, `object_action` past tense: `paywall_viewed`, `purchase_completed`,
  `sync_failed`. Screens via `screen()` from the router observer, not as events.
- Properties are ids, enums, booleans and numbers. Low cardinality for anything a
  dashboard groups by (`source`, `kind`, `context`, `reason`); never a free-text message as
  a breakdown key, truncate any message to 200 characters.
- **`source` on every step of a funnel that has more than one entry point** (paywall,
  sign-in gate), plumbed from the call site through the route to every event. The
  aggregate conversion hides which entry converts.
- **Shared names** (one name per thing, in every skill and app; the app's events constants
  class holds them): `login_started` · `login_completed` · `login_failed` (property `method`,
  `error_code`), `paywall_viewed`, `purchase_started` · `purchase_completed` ·
  `purchase_cancelled` · `purchase_failed`, `sync_failed`. Errors are not an event of our own:
  they are PostHog's `$exception` from error tracking. `grep` should find each name once.
- Count outcomes, not only starts: `_started`, `_completed`, `_cancelled`, `_failed` with a
  `reason`. A user closing a sheet is `_cancelled`, not `_failed`.
- One-shot activation markers (`first_rating`) are guarded by a persisted flag.
- Swallowed background failures (sync, uploads) get one event with `kind`, `direction`
  (`pull` = local-first fallback working, `push` = a write that did not land) and
  `terminal` (row given up on). Carry the Postgres / Storage error code, not just the
  runtime type.

## Privacy

- **Ids only.** No email, name, file path or free text in events or person properties.
  Sign-in method, platform, signup date and `is_guest` are fine.
- A `beforeSend` scrubber replaces email addresses and file paths in every string, however
  deep. Error messages are written by whatever code failed and do carry them.
- **Consent decision (recorded):** analytics is **on by default with an opt-out toggle**,
  because events carry ids only, no advertising, no cross-app tracking, no data sold or shared
  beyond PostHog (EU region) as processor. Hold all of that or switch to **opt-in**: required
  as soon as session replay is on, an advertising or attribution SDK is added, or the privacy
  page can no longer say "ids only". Opt-in means: no `setup()` network traffic until the user
  accepts a first-run choice, the same flag in `main()`. This is an engineering default, not
  legal advice; the owner confirms it for the stores' regions.
- **Guests:** do not call `identify` for anonymous Supabase sessions. PostHog's own anonymous
  id carries them (anonymous events are billed lower than identified ones); identify on
  sign-in or conversion, which merges the earlier events. Apps that already identify guests
  with `is_guest: true` may keep it; the rule above about re-identifying on conversion then
  applies.
- **Account deletion** deletes the person in PostHog (API `DELETE /persons/` by `distinct_id`,
  or the project's data-deletion request) and calls `reset()`.
- Opt-out toggle in Settings, stored on the device (SharedPreferences). Read it in `main()`
  and apply it before the first event; `setOptOut(true)` calls `Posthog().disable()`,
  which also stops session replay. The service also gates its own calls on the flag.
- Session replay, if on: `maskAllImages = true` whenever the app shows user photos.
- Keep the iOS privacy manifest (`PrivacyInfo.xcprivacy`: product interaction, diagnostics,
  linked to user id when signed in), the Play Data safety form and the privacy page in step
  with what is sent. A new kind of data is a store-form change, see app-release.

## Errors

- Use PostHog error tracking (`config.errorTrackingConfig`): `captureFlutterErrors`,
  `capturePlatformDispatcherErrors`, `captureNativeExceptions`, and
  `inAppIncludes.add('<app>')` (the bare package name; a `package:` prefix matches no frames). A hand-rolled `app_error` event sees Dart errors
  only: native crashes, ANRs and hangs stay invisible. If users report crashes and the
  tiles are quiet, believe the users.
- Caught errors that should not happen go through `analytics.error(e, where: ...)` →
  `captureException`. Skip expected ones: no network, wrong password, cancelled sheets.
- Unwrap the app's error type to report the original cause and its stack trace.

## Reading the numbers

Funnel pitfalls, HogQL via the query API, store test devices and the database sanity check:
[references/funnels-and-queries.md](references/funnels-and-queries.md). Each app keeps its
event map and dashboards in `docs/analytics-funnels.md`.

## Tests

- Test telemetry builders as pure functions (properties for a given outcome), and that a
  flow fires the right event with a fake service. Never assert against the real SDK.
- Test that sign-out resets and re-registers `build_mode`, and that the guest flip
  identifies again.
