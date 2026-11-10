---
name: app-release
description: Shipping conventions for mobile apps - Conventional Commits, branches and PRs, keeping secrets out of git (gitleaks hook + CI, .gitignore, leak response), repo visibility (public vs private tooling), versioning, changelog, pre-upload checks, App Store and Google Play review rules, the login release gate with Maestro device tests, store screenshots. Use when committing, opening a PR, bumping a version, testing login or auth flows on a device, preparing a store upload or making store images.
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

## Secrets never reach git

Every app repo has three layers, public or private. **Read
[references/secret-scanning.md](references/secret-scanning.md) when setting up a repo, when
the hook blocks a commit, or when a secret was pushed.** Templates: `templates/secrets/` in
the skills repo.

1. `.gitignore` covers `.env*` (except `*.example`), keystores, `key.properties`, `.p8` /
   `.p12` / `.pem` / `.key`, service-account JSON and Firebase client configs.
2. gitleaks pre-commit hook (`scripts/install-git-hooks.sh` once per clone) with
   `.gitleaks.toml`.
3. gitleaks in CI on every PR and push to `main`.

`bash scripts/check_secrets.sh` checks all three plus tracked files (gitleaks reads content,
so a committed keystore or `.p8` is found only there). Run it when setting up a clone and
before every store upload.

- Before `git add`: never `git add -f` an ignored file; never `git add -A` with a new env or
  key file lying around — check `git status` first.
- A false positive gets a narrow allowlist entry in `.gitleaks.toml` with a reason, never
  `--no-verify`.
- A pushed secret is leaked, even on a private repo: **rotate it first**, then remove it.
  History rewriting is cleanup, not the fix.

## Repo visibility

The app's CLAUDE.md states whether the repo is **public** or **private**. Check it before
adding or touching anything aimed at outside readers.

| Tooling | Public | Private |
|---|---|---|
| gitleaks, OSV-Scanner, Dependabot, strict analyzer, branch protection | yes | yes |
| OpenSSF Best Practices badge, Scorecard workflow + badge | yes | **no** |
| README badges that need an outside viewer, public contributor process | yes | no |

- OpenSSF Best Practices and Scorecard only work on public repos: Scorecard cannot read a
  private repo with the default token, and the badge form links files nobody outside can open.
  On a private repo, don't add them, and don't spend time keeping their answers up to date.
- When a repo goes private, remove the badges and the Scorecard workflow in one PR, and
  close the bestpractices.dev entry by hand.
- When it goes public: scan the history with gitleaks first, then add them back.

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

1. CI green on the release commit; version and changelog bumped in it;
   `bash scripts/check_secrets.sh` passes.
2. No destructive database change ships without its expand/contract plan and the
   minimum-version gate (see the supabase-app-backend skill).
3. **Login release gate.** Widget tests do not count here: they fake the provider, and login
   breaks inside native sheets and platform configuration. Follow
   [references/device-testing.md](references/device-testing.md):
   - `bash scripts/check_login_config.sh --strict` passes (entitlements, URL schemes, deep-link
     flags, SHA-1 fingerprints, Google nonce). `--strict` turns a missing SHA-1 list into a
     failure; use it in CI too.
   - The Maestro auth flows pass on the Android emulator (release APK) and the iOS simulator:
     email, Google (Android), guest → new / existing account, sign-out and deletion landing.
   - If the release touches the paywall, purchases or the entitlement webhook: the Test Store
     purchase flow passes and the server rows follow (device testing, purchases).
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

Watch for 48 hours: `login_failed` (keep an analytics alert on it, e.g. more than two
people a day), `sync_failed`, `$exception` (error tracking), crash-free sessions. Read who is affected before
acting: the store test devices are listed in the app's analytics doc.
