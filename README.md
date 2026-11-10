# skills

Conventions for Flutter apps on Riverpod, Freezed, Drift and Supabase, written as
[Claude Code skills](https://code.claude.com/docs/en/skills). The same files serve as
contributor docs: an app's README and CONTRIBUTING link here instead of keeping their own copy.

Every rule comes from code that shipped or from a production bug. Skills stay generic; each
app's `CLAUDE.md` maps them to its concrete classes and lists its deviations.

| Skill | Covers | Loads when |
|---|---|---|
| [flutter-feature-stack](skills/flutter-feature-stack/SKILL.md) | layers, folders, naming, Riverpod 3, Freezed, Drift, local-first sync ([offline-sync](skills/flutter-feature-stack/references/offline-sync.md)), navigation, deep links, errors, tests | working on Dart files in `lib/`, `test/`, `integration_test/` |
| [lean-flutter-ui](skills/lean-flutter-ui/SKILL.md) | colors, spacing tokens, anti-AI-slop, motion values, loading and offline states, text and i18n, share cards, the [UI check](skills/lean-flutter-ui/scripts/check_ui_rules.sh) | working on presentation, widgets, theme, routes |
| [supabase-app-backend](skills/supabase-app-backend/SKILL.md) | migrations ([deploys](skills/supabase-app-backend/references/migrations-and-deploys.md)), RLS, grants, storage, edge functions, native login, guest conversion, Resend, Namecheap, secrets | backend, auth, mail or DNS work |
| [app-release](skills/app-release/SKILL.md) | commits, PRs, [secret scanning](skills/app-release/references/secret-scanning.md) with the [secret check](skills/app-release/scripts/check_secrets.sh), versioning, changelog, store review checklist, login release gate with [device testing](skills/app-release/references/device-testing.md) and the [login config check](skills/app-release/scripts/check_login_config.sh), [store screenshots](skills/app-release/references/store-screenshots.md) | committing, PRs, secrets, releases, device tests, store images |
| [posthog-analytics](skills/posthog-analytics/SKILL.md) | analytics service, identify/reset, event naming, privacy (ids only, scrubber, opt-out, replay masking), error tracking, internal and store-test traffic, [funnels and HogQL](skills/posthog-analytics/references/funnels-and-queries.md) | events, consent, auth identity, reading the numbers |
| [revenuecat-purchases](skills/revenuecat-purchases/SKILL.md) | keys, entitlements and offerings, logIn/logOut, purchase flow and error mapping, trials, purchase telemetry, [server-verified Pro](skills/revenuecat-purchases/references/server-entitlement.md) via webhook | paywall, Pro gating, subscriptions, the webhook |

Plus one agent: [`pr-reviewer`](agents/pr-reviewer.md), a read-only review against all six
skills before a PR.

## Install (once per machine)

```bash
git clone https://github.com/martin-dehlan/skills ~/code/skills
~/code/skills/install.sh
```

Skills are symlinked one by one into `~/.claude/skills/`, so `git pull` updates them in place.
The agent is copied into `~/.claude/agents/`; re-run `install.sh` after pulling agent changes.
Restart Claude Code, then `/skills` and `/agents` list them. `/skill-doctor` shows how often each
skill loads and what it costs in context.

Do not also upload these skills to claude.ai: account skills sync into Claude Code as a second
copy under another name, and both would load.

## In each app repo

| File | Purpose |
|---|---|
| `CLAUDE.md` | what the app is, its deviations (they win), **Helpers** (concrete classes for the skills' generic names), commands, docs. Start from [templates/CLAUDE.app.md](templates/CLAUDE.app.md) |
| `scripts/check_ui_rules.sh`, `scripts/check_login_config.sh`, `scripts/check_claude_helpers.py`, `scripts/check_secrets.sh` | copies of the checks; CI runs them |
| `.gitleaks.toml`, `scripts/git-hooks/pre-commit`, `scripts/install-git-hooks.sh`, `.github/workflows/secret-scan.yml`, secrets block in `.gitignore` | keep secrets out of git ([templates](templates/secrets/)) |
| `android/google-sha1.txt` | SHA-1 fingerprints registered in Google Cloud (debug, upload, Play App Signing) |
| `e2e/` + `.env.e2e` (git-ignored) | Maestro auth flows and their test credentials |
| `.ui-rules-ignore` | paths that legitimately use fixed pixels (share cards) |
| `.claude/settings.json` + `.claude/hooks/format-dart.sh` | formats every Dart file Claude edits ([templates](templates/claude/)) |

## Claude Code environment for app repos

Measured over 31 sessions: about 70k tokens of context before the first reply, around 13k of it
from plugins and connectors that have nothing to do with Flutter work; 134 skills in a listing
capped at 30,000 characters; third-party plugin hooks adding about a second to every Bash call.
Skills in this repo only work well when the listing is short enough to read them.

- **Enable plugins per project, not per user.** Keep the user settings lean and put
  `enabledPlugins` in the app's `.claude/settings.json` ([template](templates/claude/settings.json)
  shows the shape). Web-framework plugins (Vercel, Next.js), chain and trading plugins, and
  design-tool connectors do not belong in a Flutter app repo.
- **Switch off connectors you do not use there** (`/mcp`): each one adds tool names to every
  session.
- **Check what a plugin sends.** One plugin posts the full text of every Bash command to its
  vendor's telemetry endpoint; its opt-out only covers prompt text. Read a plugin's hooks before
  you enable it, and never put a secret value in a command line (read it from an env file).
- **Watch the budget.** `/skill-doctor` reports skills cut from the listing and descriptions that
  are too long; descriptions plus `when_to_use` are cut at 1,536 characters, the whole listing
  at about 1 % of the context window.
- **Target:** a fresh session in an app repo lists fewer than 30 skills.

## How this repo grows

When a bug turns out to be a class rather than a one-off (it happened twice, or it would
happen in the next app too), add one generic rule with a short reason to the matching skill.
The `pr-reviewer` flags these as `Skill candidate:` on every fix branch. Add the rule
in the same PR as the fix or right after it. App names, issue numbers and concrete class
names stay out of the skills; they belong in the app's `CLAUDE.md`. Keep each `SKILL.md`
short: details go to `references/`, which Claude reads only when the task needs them.
