---
name: app-setup
description: Set up a new Flutter app on the Riverpod, Freezed, Drift, Supabase stack - create the project, roll in the skills' scripts, hooks and CI, fill the CLAUDE.md template. Manual only; run it as /app-setup for a new app.
disable-model-invocation: true
---

# Set up a new app

The skills repo is the source of truth for scripts and templates; resolve its path with
`dirname "$(dirname "$(readlink ~/.claude/skills/app-release)")"` (call it `$SKILLS`).

1. **Ask once** (all in one question): app name, package/bundle id, domain, public or private
   repo, auth (required, optional, guest), whether it has a paywall. Decide everything else.
2. `flutter create --org <org> --project-name <name> .`, then add the stack to `pubspec.yaml`
   (flutter_riverpod + riverpod_annotation + riverpod_generator, freezed, drift + drift_dev,
   go_router, supabase_flutter, posthog_flutter, purchases_flutter if paid, build_runner).
   Folder skeleton and naming: flutter-feature-stack skill.
3. **Roll in the shared files:** `bash $SKILLS/sync.sh .` (check scripts, hooks, secret scan,
   `.claude/` settings and rules, `CLAUDE.md` seed). Copy `$SKILLS/templates/ci/*` into
   `.github/` (`ci.yml`, `osv-scanner.yml` under `workflows/`, `dependabot.yml`) and merge
   `$SKILLS/templates/analysis_options.yaml`.
4. **Fill `CLAUDE.md`** from the seed: what the app is, deviations, reference files (point at
   real files once they exist), *Not adopted yet* (list everything the skills ask for that the
   new app does not have yet), Helpers rows as classes appear.
5. `bash scripts/install-git-hooks.sh`; create `.env.example`, `.env.tools.example`,
   git-ignore the real files; copy the secrets block from `templates/secrets/gitignore-secrets.txt`.
6. Supabase: create dev and prod projects, `supabase init`, first migration from
   `skills/supabase-app-backend/references/migration-template.sql`.
7. First commit on `main`, then everything else by branch and PR (`/ship`). Finish with
   `bash scripts/check_secrets.sh` and `python3 scripts/check_claude_helpers.py`.
