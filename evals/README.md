# Evals

Does a skill trigger, and does it change the answer? `prompts.tsv` has five or more realistic prompts per
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
| flutter-feature-stack | not run | not run | |
| lean-flutter-ui | not run | not run | |
| supabase-app-backend | not run | not run | |
| app-release | not run | not run | |
| posthog-analytics | not run | not run | |
| revenuecat-purchases | not run | not run | |

## Monthly check (first Monday)

1. `/skill-doctor` in an app repo: listing budget, truncated descriptions.
2. `evals/run.sh` and `evals/run.sh --off`; update the table.
3. `skills/app-release/references/platform-facts.md`: re-check every row if its date is older
   than 90 days.
4. Open `skill-candidate` issues: each gets a rung (README, "How this repo grows") the same week;
   one without a verdict after two weeks is labelled `parked`.
5. **Prune**, per skill, before any new content:
   - the lint's size table: a file within 10 % of its budget gets a prune PR this month;
   - prose a check script now enforces shrinks to the pattern's name in the Enforcement list;
   - a rule whose prompt is `lift: no` twice in a row is general model knowledge: delete it or
     merge it into a neighbour, keep the prompt one more month as a guard;
   - a rule no candidate, reviewer finding or eval cited for six months moves to a reference or goes;
   - anything said twice across skills is kept once and linked (the path rules are the only
     intended copy);
   - `parked` candidates older than three months without a second occurrence: close as one-off;
   - after a new model generation, run the whole set `--off`: rules it follows unprompted are
     prune candidates.
6. Note every addition and removal in `CHANGELOG.md` (removals with the reason: script, no lift,
   unused).
