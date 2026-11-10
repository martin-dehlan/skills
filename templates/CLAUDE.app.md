# CLAUDE.md — <App>

<One or two sentences: what the app is and for whom.> Domain `<domain>`, package `<package>`.

Shared rules come from the skills in https://github.com/martin-dehlan/skills. This file lists
only what is specific to <App>. **Where it differs from a skill, this file wins.**

## Load the skill before you start

This file is always in context, a skill is not. Load the matching skill (Skill tool) before:

| You are about to | Load |
|---|---|
| change Dart code in `lib/` or `test/` | `flutter-feature-stack` |
| touch a screen, widget, theme or route | `lean-flutter-ui` |
| write a migration, policy, edge function, login or mail code | `supabase-app-backend` |
| add or change an event, consent or identity call | `posthog-analytics` |
| touch the paywall, Pro gating or the webhook | `revenuecat-purchases` |
| commit, open a PR, bump a version, upload to a store | `app-release` |

Before a PR, run the `pr-reviewer` agent.

## Invariants

Each of these was a production bug. They hold even when no skill is loaded.

1. Saving never waits on the network: write Drift, return, sync afterwards.
2. Every network call goes through the timeout helper.
3. Every user-written table has `isSynced`, `syncAttempts` and an outbox flusher; a pull never overwrites an unsynced row.
4. Timestamps go to Supabase as `toUtc().toIso8601String()`.
5. Drift reads are scoped to the current user id.
6. A schema change bumps `schemaVersion` and adds a migration step and a test from the previous version.
7. A new table gets RLS, its policies and its explicit grants in the same migration. Never edit a migration that ran on prod.
8. Policies use `(select auth.uid())`; `security definer` functions set `search_path = ''`.
9. Secrets: only publishable keys in `.env`; everything else in `.env.tools`. Never put a secret in a command line, a log or a commit.
10. Never `--no-verify`, never force-push `main`.
11. `ref.watch` in `build`, `ref.read` in callbacks; check `ref.mounted` after every `await`.
12. After `await` in a widget, check `mounted`; loading flags reset in `finally`.
13. Analytics sends never throw and are never awaited on a user path; events carry ids only, no email or free text.
14. Guests are not identified in RevenueCat; a purchase waits for the pending `logIn`.
15. Pro that unlocks server data is checked on the server, never by the client flag alone.
16. Colors, spacing, radii and text come from the theme tokens; no fixed pixels or `Color(0x…)` in screens.
17. Apple and Google login pass a nonce; the release is gated by `check_login_config.sh --strict`.
18. A change is not done until `dart format`, `flutter analyze`, `flutter test` and the checks below pass.

## Deviations

- **Repo:** <public / private>. Private → no OpenSSF badge or Scorecard (app-release skill).
- **Source of truth:** <Drift for user data / Supabase for served content>. <Exceptions.>
- **Auth:** <required / optional / guest mode>. <Router guard or none.>
- **Navigation:** <shell, tabs, deep links, orientation>.
- **Tests layout:** <test/features/... mirroring lib/ | test/unit + test/widget>.
- <Anything else that differs from the skills.>

## Reference files

Copy the shape of these instead of inventing one. Replace with the real paths.

| For a new | Copy from |
|---|---|
| repository + DAO | `lib/features/<f>/data/<name>_repository.dart` |
| outbox flusher | `<path>` |
| screen (list + detail) | `<path>` |
| widget with loading, empty and error states | `<path>` |
| controller / provider test | `test/<path>` |
| migration with RLS and grants | `supabase/migrations/<file>.sql` |

## Not adopted yet

What the skills ask for and this app does not have, so nobody assumes it exists. Delete a
line when it lands; delete the section when empty.

- <e.g. `android/google-sha1.txt`, `e2e/` flows, server-verified Pro webhook, consent screen, `.ui-rules-ignore`>

## Helpers

The concrete classes behind the generic names in the skills. Fill in what exists; delete
rows the app does not have (and list them under "Not adopted yet").

| Skills say | In <App> |
|---|---|
| responsive tokens | `lib/common/utils/responsive.dart`: <getter names> |
| network-timeout helper | <name + path> |
| UTC converter | <name + path> |
| error mapping / error widgets | <AppError mapper, error state widgets> |
| snackbar | <name> |
| unwrap provider errors | <name> |
| provider retry config | <path> |
| motion setting | <name> |
| skeleton widgets | <names> |
| hyphenation widget | <name> |
| pending-media store | <name + path> |
| signed-URL image widget | <name> |
| outbox flushers | <path> |
| sync failure event | <analytics method> |
| analytics service / event names | <service + path>, <events constants class> |
| guest check | <name + path> |
| Pro repository / entitlement | <repository + path>, entitlement `<id>`, webhook `<function>` |
| paywall opener | <name + path> |
| deep-link holder | <name + path> |
| env loader | <name + path> |
| test helpers | `test/helpers/<files>` |
| fixed-canvas renders (`.ui-rules-ignore`) | <paths> |
| e2e | app id `<id>`, flows in `e2e/`, credentials in `.env.e2e`, Supabase test users |

## Commands

```bash
bash scripts/install-git-hooks.sh          # once per clone: gitleaks pre-commit hook
dart run build_runner build
dart format . && flutter analyze && flutter test
bash scripts/check_ui_rules.sh             # UI tokens, blur, elevation, fixed pixels
python3 scripts/check_claude_helpers.py    # Helpers table still matches the code
bash scripts/check_secrets.sh              # secret hygiene (hook, CI, .gitignore, history)
bash scripts/check_login_config.sh --strict   # before a store upload
bash <skills>/sync.sh --check .            # scripts still match the skills repo
```

## Docs

- `docs/...`: <what lives where>

## Secrets

`.env` (bundled, publishable keys only) and `.env.tools` (never bundled). See the
supabase-app-backend skill.
