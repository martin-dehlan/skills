---
name: app-release
description: Shipping conventions for mobile apps - Conventional Commits, branches and PRs, versioning, changelog, pre-upload checks, App Store and Google Play review rules, the login release gate with Maestro device tests, store screenshots. Use when committing, opening a PR, bumping a version, testing login or auth flows on a device, preparing a store upload or making store images.
---

# Shipping an app

App-specific details (test devices, dashboards, alerts) live in the repo's CLAUDE.md and docs.

## Commits

Format `type(scope): subject`. Subject ≤ 60 chars, lowercase, imperative, no trailing period.
Scope = feature folder or area (`auth`, `profile`, `router`, `android`).

| Type | When |
|---|---|
| `feat` | new functionality |
| `fix` | bug fix |
| `refactor` | code change without behaviour change |
| `perf` | faster, same behaviour |
| `chore` | build, deps, tooling, releases |
| `docs` | docs or comments only |
| `test` | tests only |

One logical change per commit; related files that form one concept (controller + codegen + UI)
go together. Push after every commit. Never force-push `main`, never `--no-verify`.

## Branches and PRs

| Change | Where |
|---|---|
| Feature | `feat/<name>` → PR |
| Fix that needs review | `fix/<name>` → PR |
| Docs or policy | `docs/<name>` → PR |
| Trivial (typo, dep bump, one line) | direct to `main` |

- One self-contained concept per PR. Title = the squash commit (Conventional Commits).
- Body: summary, `Fixes #n` / `Closes #n` for every issue it resolves (so the backlog closes
  itself), test plan with what ran and what was checked on a device.
- Squash-merge. Before pushing: `dart format`, `flutter analyze`, `flutter test`,
  `build_runner` when annotations changed, UI check when UI changed, smoke test of the flow.
- Before opening the PR, run the `pr-reviewer` agent on the branch.

## Versioning

`MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`.

| Bump | When |
|---|---|
| MAJOR | breaking changes; the first prod release with a paywall is `1.0.0` |
| MINOR | a feature batch |
| PATCH | fixes only |
| BUILD | `+1` on every store upload (TestFlight / Play internal), always |

Bump when the batch ships to a store, not when work starts.

## Changelog (if the app has `CHANGELOG.md`)

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/): `## [x.y.z+b] — YYYY-MM-DD`, a
one-line summary, then `Added` / `Changed` / `Fixed` / `Security`. **Security is always
present** (write "None." when nothing was fixed). Entries describe what the user notices, with
the issue or PR number.

## Before every store upload

1. CI green on the release commit; version and changelog bumped in it.
2. No destructive database change ships without its expand/contract plan and the
   minimum-version gate (see the supabase-app-backend skill).
3. **Login release gate.** Widget tests do not count here: they fake the provider, and login
   breaks inside native sheets and platform configuration. Follow
   [references/device-testing.md](references/device-testing.md):
   - `bash scripts/check_login_config.sh` passes (entitlements, URL schemes, deep-link flags,
     SHA-1 fingerprints).
   - The Maestro auth flows pass on the Android emulator (release APK) and the iOS simulator:
     email, Google (Android), guest → new / existing account, sign-out and deletion landing.
     Claude runs them when an emulator or simulator is reachable; otherwise it says so.
   - Manual, release build on a real iPhone: Apple and Google sign-in.
   - Record what ran, on which devices, with which result in the release PR. A failure blocks
     the upload.
4. Store review checklist below.
5. Screenshots updated if the UI in them changed ([references/store-screenshots.md](references/store-screenshots.md)).

## App Store review: rejections that already happened

Each row below was a real rejection. Check all of them before every submission:

| Guideline | Check |
|---|---|
| 4.8 Login services | Google login exists → Sign in with Apple is offered too |
| 2.1(a) on iPad | Test on an iPad: reviewers use one even for iPhone apps (a web OAuth spinner hung only there) |
| 2.1 Information | Review notes contain a working demo account with realistic data, and Pro access if it is paid |
| 2.3.10 Other platforms | No "Google Play" or Android text on iOS, including subscription status and "manage" links |
| 4 Design | Apple button is the official `SignInWithAppleButton`, outlined/white on dark backgrounds |
| 5.1.1(v) | Account deletion is reachable inside the app |
| 3.1.2 Subscriptions | Paywall shows price per period, trial terms, restore purchases, Terms of Use and Privacy Policy links |
| 5.1.1 Permissions | Every permission string says why (camera: "to scan a label") |

## Google Play

- Target the API level Play currently requires (watch the Play Console warnings).
- Update the Data safety form when collected data changes.
- Account deletion: in the app **and** a web page to request it.
- Play screenshots are a separate 9:16 export (see the screenshots reference).

## After release

Watch for 48 hours: `auth_login_failed` (keep an analytics alert on it, e.g. more than two
people a day), `sync_failed`, `app_error`, crash-free sessions. Read who is affected before
acting: the store test devices are listed in the app's analytics doc.
