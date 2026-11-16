#!/usr/bin/env bash
# The lint must go red on a broken link and on an unknown frontmatter field.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp -R "$ROOT/skills" "$ROOT/agents" "$ROOT/templates" "$tmp"/; mkdir "$tmp/tests"; cp "$ROOT/tests/lint_skills.py" "$ROOT/tests/size_budget.tsv" "$tmp/tests/"
fail=0
python3 "$tmp/tests/lint_skills.py" >/dev/null || { echo "FAIL clean copy is red"; fail=1; }
echo "[x](nope/missing.md)" >> "$tmp/skills/app-release/SKILL.md"
python3 "$tmp/tests/lint_skills.py" >/dev/null && { echo "FAIL broken link not caught"; fail=1; } || echo "ok   broken link is red"
cp "$ROOT/skills/app-release/SKILL.md" "$tmp/skills/app-release/SKILL.md"
sed -i.bak '2a\
bogus: 1' "$tmp/skills/app-release/SKILL.md"
python3 "$tmp/tests/lint_skills.py" >/dev/null && { echo "FAIL unknown field not caught"; fail=1; } || echo "ok   unknown field is red"
cp "$ROOT/skills/app-release/SKILL.md" "$tmp/skills/app-release/SKILL.md"

# budgets
red() { python3 "$tmp/tests/lint_skills.py" >/dev/null && { echo "FAIL $1 not caught"; fail=1; } || echo "ok   $1 is red"; }
green() { python3 "$tmp/tests/lint_skills.py" >/dev/null && echo "ok   $1 is green" || { echo "FAIL $1 is red"; fail=1; }; }
restore() { cp "$ROOT/$1" "$tmp/$1"; }
for i in $(seq 1 40); do echo "line $i" >> "$tmp/skills/app-release/SKILL.md"; done
red "SKILL.md over 200 lines"; restore skills/app-release/SKILL.md
python3 -c "print('x' * 2000)" >> "$tmp/skills/lean-flutter-ui/SKILL.md"
red "SKILL.md over 10 KB"; restore skills/lean-flutter-ui/SKILL.md
for i in $(seq 1 12); do echo "line $i" >> "$tmp/skills/ship/SKILL.md"; done
red "workflow skill over 40 lines"; restore skills/ship/SKILL.md
for i in $(seq 1 5); do echo "- bullet $i" >> "$tmp/templates/claude/rules/dart-ui.md"; done
red "path rule over 15 bullets"; restore templates/claude/rules/dart-ui.md
echo "one more" >> "$tmp/skills/flutter-feature-stack/SKILL.md"
red "grandfathered file grows"; restore skills/flutter-feature-stack/SKILL.md
sed -i.bak '10,150d' "$tmp/skills/flutter-feature-stack/SKILL.md"
red "obsolete ceiling row"; restore skills/flutter-feature-stack/SKILL.md
green "restored copy"
exit $fail
