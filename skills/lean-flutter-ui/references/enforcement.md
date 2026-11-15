# Enforcement: the UI check in CI

Read when wiring the check into an app's CI or when adding an exception.

[`scripts/check_ui_rules.sh`](../scripts/check_ui_rules.sh) checks only lines added since the
base branch, so old code never blocks a PR. It covers fixed spacing, padding, font sizes and
radii, raw colors, gradients, `BackdropFilter`, blur above 10, elevation above 1, emoji,
`MediaQuery.of(context).size`, `_build` methods and `print`.
Nesting depth, hierarchy and decorative icons stay a review matter. A base ref that does not
exist exits 2, never "OK"; `--file <path>` checks every line of one file. Every app keeps a copy
at `scripts/check_ui_rules.sh` and runs it in CI on pull requests (checkout with `fetch-depth: 0`):

```yaml
      - name: ui rules (added lines only)
        if: github.event_name == 'pull_request'
        run: bash scripts/check_ui_rules.sh origin/${{ github.base_ref }}
```

Exceptions:
- `.ui-rules-ignore` at the repo root: one git pathspec per line, for code that legitimately
  uses fixed pixels (e.g. `lib/features/<feature>/presentation/cards/*` for share cards).
- `// ui-rules-ok: <reason>` on the line itself, for a single justified case (the reason is
  required). Prefer a theme color or a new token over the marker.
