# CLAUDE.md — <App>

<One or two sentences: what the app is and for whom.> Domain `<domain>`, package `<package>`.

Shared rules come from the skills in https://github.com/martin-dehlan/skills
(`flutter-feature-stack`, `lean-flutter-ui`, `supabase-app-backend`, `app-release`).
This file lists only what is specific to <App>. **Where it differs from a skill, this file wins.**

## Deviations

- **Source of truth:** <Drift for user data / Supabase for served content>. <Exceptions.>
- **Auth:** <required / optional / guest mode>. <Router guard or none.>
- **Navigation:** <shell, tabs, deep links, orientation>.
- **Tests layout:** <test/features/... mirroring lib/ | test/unit + test/widget>.
- <Anything else that differs from the skills.>

## Helpers

The concrete classes behind the generic names in the skills. Fill in what exists; delete
rows the app does not have.

| Skills say | In <App> |
|---|---|
| responsive tokens | `lib/common/utils/responsive.dart`: <getter names> |
| network-timeout helper | <name + path> |
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
| test helpers | `test/helpers/<files>` |
| fixed-canvas renders (`.ui-rules-ignore`) | <paths> |

## Commands

```bash
dart run build_runner build
dart format . && flutter analyze && flutter test
bash scripts/check_ui_rules.sh
```

## Docs

- `docs/...`: <what lives where>

## Secrets

`.env` (bundled, publishable keys only) and `.env.tools` (never bundled). See the
supabase-app-backend skill.
