#!/usr/bin/env bash
# Fixture test for the Claude hooks. Run: bash tests/hooks_test.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); H="$ROOT/templates/claude/hooks"
app=$(mktemp -d); trap 'rm -rf "$app"' EXIT; cd "$app" || exit 1
git init -q -b main; git config user.email t@t; git config user.name t
mkdir -p scripts lib/features/a/domain lib/features/a/presentation
# stub check: fails for any file that mentions "flutter/material" (the real checks are tested on their own)
printf '#!/usr/bin/env bash\ngrep -q "flutter/material" "$2" && { echo "$2: stub violation"; exit 1; }; exit 0\n' > scripts/check_layers.sh
chmod +x scripts/check_layers.sh
echo "class A {}" > lib/features/a/domain/a.entity.dart; git add -A; git commit -qm b
export CLAUDE_PROJECT_DIR="$app"
fail=0
has() { if printf '%s' "$2" | grep -q "$3"; then echo "ok   $1"; else echo "FAIL $1 :: $2"; fail=1; fi; }
hasnt() { if printf '%s' "$2" | grep -q "$3"; then echo "FAIL $1 :: $2"; fail=1; else echo "ok   $1"; fi; }
j() { python3 -c 'import json,sys; print(json.dumps({"tool_input":{sys.argv[1]:sys.argv[2]}}))' "$1" "$2"; }

has   "generated file denied"      "$(j file_path /x/lib/a.g.dart | "$H/guard-files.sh")" '"deny"'
has   "freezed file denied"        "$(j file_path /x/lib/a.freezed.dart | "$H/guard-files.sh")" '"deny"'
has   "real .env denied"           "$(j file_path /x/.env.tools | "$H/guard-files.sh")" '"deny"'
hasnt ".env.example allowed"       "$(j file_path /x/.env.example | "$H/guard-files.sh")" 'deny'
hasnt "normal dart allowed"        "$(j file_path /x/lib/a.dart | "$H/guard-files.sh")" 'deny'

echo "import 'package:flutter/material.dart';" >> lib/features/a/domain/a.entity.dart
has   "layer violation fed back"   "$(j file_path "$app/lib/features/a/domain/a.entity.dart" | "$H/check-edited-dart.sh")" 'additionalContext'
hasnt "clean file silent"          "$(j file_path "$app/lib/features/a/presentation/none.dart" | "$H/check-edited-dart.sh")" 'additionalContext'

has   "pr create blocked"          "$(j command 'gh pr create --title x' | "$H/gate-pr-create.sh")" '"deny"'
hasnt "other command passes"       "$(j command 'git status' | "$H/gate-pr-create.sh")" 'deny'
hasnt "override passes"            "$(j command 'SKIP_PR_REVIEW=1 gh pr create' | "$H/gate-pr-create.sh")" 'deny'
mark() { d="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)/pr-reviews"; mkdir -p "$d"; touch "$d/$(git -C "$1" rev-parse HEAD)"; }
mark .
hasnt "marker for HEAD passes"     "$(j command 'gh pr create' | "$H/gate-pr-create.sh")" 'deny'
git commit -qam next
has   "new commit needs new review" "$(j command 'gh pr create' | "$H/gate-pr-create.sh")" '"deny"'
git rev-parse HEAD > "$(git rev-parse --git-path pr-reviewed)"
hasnt "legacy marker still passes" "$(j command 'gh pr create' | "$H/gate-pr-create.sh")" 'deny'
rm "$(git rev-parse --git-path pr-reviewed)"

# a worktree: the session (and the hook) stays in the main checkout
wt="$app-wt"; git worktree add -q -b fix/x "$wt"; ( cd "$wt" && echo y > y && git add y && git commit -qm y )
trap 'rm -rf "$app" "$wt"' EXIT
has   "worktree unreviewed blocked" "$(j command "cd $wt && gh pr create --title x" | "$H/gate-pr-create.sh")" '"deny"'
mark .
has   "main marker does not cover worktree" "$(j command "cd $wt && gh pr create" | "$H/gate-pr-create.sh")" '"deny"'
mark "$wt"
hasnt "worktree reviewed passes"   "$(j command "cd $wt && flutter test && gh pr create --title x" | "$H/gate-pr-create.sh")" 'deny'
hasnt "--head reviewed passes"     "$(j command 'gh pr create --head fix/x --title x' | "$H/gate-pr-create.sh")" 'deny'
( cd "$wt" && git commit -qm z --allow-empty )
has   "--head new commit blocked"  "$(j command 'gh pr create --head fix/x' | "$H/gate-pr-create.sh")" '"deny"'
has   "missing cd dir blocked"     "$(j command 'cd /nope/x && gh pr create' | "$H/gate-pr-create.sh")" '"deny"'

# session start
cfg=$(mktemp -d); mkdir -p "$cfg/skills/lean-flutter-ui" "$cfg/agents"; touch "$cfg/skills/lean-flutter-ui/SKILL.md" "$cfg/agents/pr-reviewer.md"
up=$(mktemp -d); trap 'rm -rf "$app" "$wt" "$cfg" "$up"' EXIT
git clone -q "$app" "$up/c"; ( cd "$up/c" && git config user.email t@t && git config user.name t )
hasnt "session start silent when current" "$(cd "$up/c" && CLAUDE_CONFIG_DIR=$cfg "$H/session-start.sh")" 'systemMessage'
mkdir -p .claude; echo '{}' > .claude/settings.json; git add .claude; git commit -qm hooks
( cd "$up/c" && git fetch -q origin )
has   "stale hooks announced"      "$(cd "$up/c" && CLAUDE_CONFIG_DIR=$cfg "$H/session-start.sh")" 'behind origin/main'
echo z > z; git add z; git commit -qm other; ( cd "$up/c" && git pull -q --ff-only origin main && git commit -q --allow-empty -m mine && git fetch -q origin )
hasnt "diverged branch not stale"  "$(cd "$up/c" && CLAUDE_CONFIG_DIR=$cfg "$H/session-start.sh")" 'behind'
rm "$cfg/agents/pr-reviewer.md"
has   "missing agent announced"    "$(cd "$up/c" && CLAUDE_CONFIG_DIR=$cfg "$H/session-start.sh")" 'pr-reviewer agent not installed'
has   "no git dir is fine"         "$(cd "$cfg" && CLAUDE_CONFIG_DIR=$cfg "$H/session-start.sh"; echo rc=$?)" 'rc=0'

t0=$(python3 -c 'import time;print(time.time())')
j file_path /x/lib/a.dart | "$H/guard-files.sh" >/dev/null
t1=$(python3 -c 'import time;print(time.time())')
python3 -c "import sys; sys.exit(0 if $t1-$t0 < 0.3 else 1)" && echo "ok   guard under 300 ms" || { echo "FAIL guard slow"; fail=1; }
exit $fail
