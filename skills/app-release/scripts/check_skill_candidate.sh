#!/usr/bin/env bash
# check_skill_candidate.sh: a PR that corrects shipped UI must say what the skills learn from it.
#
# Usage:  TITLE="<pr title>" BODY="<pr body>" scripts/check_skill_candidate.sh [base-ref]
# Exit:   0 not a UI correction, or it has the line; 1 the line is missing; 2 base ref missing
#
# A UI correction is a PR titled fix(...) or design(...) whose diff touches presentation code,
# widgets, the theme or l10n copy. Its body needs one line starting with "Skill candidate:",
# either the issue in the skills repo or "none (one-off: <reason>)". /ship writes it from the
# pr-reviewer's output.
set -euo pipefail
base="${1:-origin/main}"
title="${TITLE:-}"
body="${BODY:-}"

if ! printf '%s' "$title" | grep -qE '^(fix|design)(\([^)]*\))?!?:'; then
  echo "skill candidate: not a fix or design PR"; exit 0
fi
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "check_skill_candidate: base ref '$base' not found (CI needs fetch-depth: 0)" >&2; exit 2
fi
ui=$(git diff --name-only "$base"...HEAD -- 'lib/**/presentation/**' 'lib/**/widgets/**' \
  'lib/common/theme/**' 'lib/l10n/*.arb' | head -5)
if [ -z "$ui" ]; then
  echo "skill candidate: no UI files changed"; exit 0
fi
if printf '%s\n' "$body" | grep -qE '^[[:space:]>*_-]*Skill candidate:'; then
  echo "skill candidate: $(printf '%s\n' "$body" | grep -m1 -E 'Skill candidate:' | sed 's/^[[:space:]>*_-]*//')"; exit 0
fi
echo "This PR corrects UI but its body has no 'Skill candidate:' line. UI files:"
printf '  %s\n' $ui
echo
echo "Run the pr-reviewer (or /ship); it ends with a Skill candidate line. Put it in the PR body:"
echo "  Skill candidate: https://github.com/martin-dehlan/skills/issues/<n>"
echo "  Skill candidate: none (one-off: <reason>)"
exit 1
