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
| [app-release](skills/app-release/SKILL.md) | commits, PRs, versioning, changelog, store review checklist, login release gate with [device testing](skills/app-release/references/device-testing.md) and the [login config check](skills/app-release/scripts/check_login_config.sh), [store screenshots](skills/app-release/references/store-screenshots.md) | committing, PRs, releases, device tests, store images |

Plus one agent: [`pr-reviewer`](agents/pr-reviewer.md), a read-only review against all four
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
| `scripts/check_ui_rules.sh`, `scripts/check_login_config.sh` | copies of the checks; CI runs them |
| `android/google-sha1.txt` | SHA-1 fingerprints registered in Google Cloud (debug, upload, Play App Signing) |
| `e2e/` + `.env.e2e` (git-ignored) | Maestro auth flows and their test credentials |
| `.ui-rules-ignore` | paths that legitimately use fixed pixels (share cards) |
| `.claude/settings.json` + `.claude/hooks/format-dart.sh` | formats every Dart file Claude edits ([templates](templates/claude/)) |

## How this repo grows

When a bug turns out to be a class rather than a one-off (it happened twice, or it would
happen in the next app too), add one generic rule with a short reason to the matching skill,
in the same PR as the fix or right after it. App names, issue numbers and concrete class
names stay out of the skills; they belong in the app's `CLAUDE.md`. Keep each `SKILL.md`
short: details go to `references/`, which Claude reads only when the task needs them.
