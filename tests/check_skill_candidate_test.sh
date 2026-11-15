#!/usr/bin/env bash
# Fixture test for skills/app-release/scripts/check_skill_candidate.sh
set -uo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/skills/app-release/scripts/check_skill_candidate.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT; cd "$tmp" || exit 1
git init -q -b main; git config user.email t@t; git config user.name t
git commit -q --allow-empty -m init; git checkout -q -b fix
mkdir -p lib/features/a/presentation/widgets lib/features/a/data
echo x > lib/features/a/presentation/widgets/card.widget.dart; git add -A; git commit -qm ui
fails=0
run() { TITLE="$2" BODY="$3" bash "$script" main >/dev/null 2>&1; c=$?; [ "$c" = "$4" ] && echo "ok   $1" || { echo "FAIL $1 (exit $c, expected $4)"; fails=1; }; }
run "fix + UI without line fails"       "fix(player): calmer error" "Closes #1" 1
run "fix + UI with issue link passes"   "fix(player): calmer error" $'Closes #1\n\nSkill candidate: https://github.com/x/skills/issues/9' 0
run "bullet and bold line passes"       "fix: x" $'- **Skill candidate:** none (one-off: copy typo)' 0
run "design PR without line fails"      "design(menu): tighter card" "" 1
run "feat PR is not checked"            "feat(player): new card" "" 0
run "mention mid-sentence is not a line" "fix: x" "we should add a Skill candidate: later" 1
git checkout -q main; git checkout -q -b data; echo y > lib/features/a/data/repo.dart; git add -A; git commit -qm data
run "fix without UI files passes"       "fix(sync): retry" "" 0
TITLE="fix: x" bash "$script" nope >/dev/null 2>&1; [ $? = 2 ] && echo "ok   missing base exits 2" || { echo "FAIL missing base"; fails=1; }
exit $fails
