#!/usr/bin/env bash
# The lint must go red on a broken link and on an unknown frontmatter field.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp -R "$ROOT/skills" "$ROOT/agents" "$ROOT/templates" "$tmp"/; mkdir "$tmp/tests"; cp "$ROOT/tests/lint_skills.py" "$tmp/tests/"
fail=0
python3 "$tmp/tests/lint_skills.py" >/dev/null || { echo "FAIL clean copy is red"; fail=1; }
echo "[x](nope/missing.md)" >> "$tmp/skills/app-release/SKILL.md"
python3 "$tmp/tests/lint_skills.py" >/dev/null && { echo "FAIL broken link not caught"; fail=1; } || echo "ok   broken link is red"
cp "$ROOT/skills/app-release/SKILL.md" "$tmp/skills/app-release/SKILL.md"
sed -i.bak '2a\
bogus: 1' "$tmp/skills/app-release/SKILL.md"
python3 "$tmp/tests/lint_skills.py" >/dev/null && { echo "FAIL unknown field not caught"; fail=1; } || echo "ok   unknown field is red"
exit $fail
