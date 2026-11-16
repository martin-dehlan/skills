# Changelog

Apps read this to see what changed after `git pull` / `sync.sh`. One line per merged change,
newest first, grouped by month. Add the line in the same PR.

## 2026-11

- `check_file_sizes.sh` skips Drift's generated `*.steps.dart` (schema steps grow with every migration). Apps: run `sync.sh`.
- Hooks: the PR gate checks the commit that becomes the PR (`--head`, or the worktree named by `cd`), markers per commit in the common git dir (`pr-reviews/<sha>`); new `session-start.sh` announces stale hooks and missing skills; `install.sh --clone` for cloud sessions. Apps: run `sync.sh`, then add the `SessionStart` entry from `templates/claude/settings.json` to `.claude/settings.json` (seed file, not synced).
- `lean-flutter-ui`: off-screen renders, CI wiring and the widget sample move to `references/` behind a "read when" table (177 → 136 lines); new "Calm states" (a fixable state is an accent line that opens the fix, a recoverable failure in the surrounding style, status never changes layout), fixed sets as one row of equal tiles, lists in sheets stop at the default height. `rules/dart-ui.md`: one bullet on `cs.error`. `revenuecat-purchases`: where Pro is offered. Five eval prompts. Apps: copy the new `dart-ui.md` bullet (seed file).
- Intake: the reviewer writes a `Skill candidate:` line with a rung for every correction, `/ship` files it as a `skill-candidate` issue here (or +1), app CI fails a UI fix PR without the line (`check_skill_candidate.sh`, workflow `skill-candidate.yml`), issue template. Apps: `sync.sh` adds the script and the workflow.
- Growth: admission ladder (seven rungs, cheapest place that prevents the repeat), size budgets in the lint (`SKILL.md` 200 lines / 10 KB, workflow skills 40, references 150, path rules 15 bullets, ratchet in `tests/size_budget.tsv`), monthly prune pass, PR template for skill changes.
- Audit plan started (issues #9 to #34): skills no longer use `paths:`, `check_ui_rules.sh` fails closed, installer uses a live worktree, `check_login_config.sh --strict`, `sync.sh`, CLAUDE.md template with invariants, path-scoped rules, hooks, layer and size checks, CI and analyzer templates, repo CI, reviewer loads skills by diff, explicit grants and new key names, account lifecycle and push references, pull-side sync, version gate, UI scale and accessibility, one set of event names, entitlement table, platform facts, workflow skills `/ship` `/release` `/app-setup`, evals.
