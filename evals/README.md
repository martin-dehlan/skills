# Evals

Does a skill trigger, and does it change the answer? `prompts.tsv` has five realistic prompts per
skill with a regex the answer must match and one it must not.

```bash
evals/run.sh                    # skills on (your installed set)
evals/run.sh --off              # baseline without skills (empty config dir; log in once there)
evals/run.sh --skill app-release
```

Compare the two totals per skill. A skill that scores the same on and off is not earning its
listing line: fix its description or cut it. Results land in `evals/results/` (git-ignored);
copy the two totals into the table below with the date.

## Baseline

| Skill | On | Off | Date |
|---|---|---|---|
| flutter-feature-stack | 2/5 | not run | 2026-11-10 |
| lean-flutter-ui | 4/5 | not run | 2026-11-10 |
| supabase-app-backend | 5/5 | not run | 2026-11-10 |
| app-release | 5/5 | not run | 2026-11-10 |
| posthog-analytics | 5/5 | not run | 2026-11-10 |
| revenuecat-purchases | 3/5 | not run | 2026-11-10 |

## Monthly check (first Monday)

1. `/skill-doctor` in an app repo: listing budget, truncated descriptions.
2. `evals/run.sh` and `evals/run.sh --off`; update the table.
3. `skills/app-release/references/platform-facts.md`: re-check every row if its date is older
   than 90 days.
4. Open `Skill candidate` PRs: each merges the same day as the fix in the app; close or merge
   what is older than two weeks.
5. Note changes in `CHANGELOG.md`.
