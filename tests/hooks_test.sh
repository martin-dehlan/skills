#!/usr/bin/env bash
# Fixture test for the Claude hooks. Run: bash tests/hooks_test.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); H="$ROOT/templates/claude/hooks"
app=$(mktemp -d); trap 'rm -rf "$app"' EXIT; cd "$app"
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
git rev-parse HEAD > "$(git rev-parse --git-path pr-reviewed)"
hasnt "marker for HEAD passes"     "$(j command 'gh pr create' | "$H/gate-pr-create.sh")" 'deny'
git commit -qam next
has   "new commit needs new review" "$(j command 'gh pr create' | "$H/gate-pr-create.sh")" '"deny"'

t0=$(python3 -c 'import time;print(time.time())')
j file_path /x/lib/a.dart | "$H/guard-files.sh" >/dev/null
t1=$(python3 -c 'import time;print(time.time())')
python3 -c "import sys; sys.exit(0 if $t1-$t0 < 0.3 else 1)" && echo "ok   guard under 300 ms" || { echo "FAIL guard slow"; fail=1; }
exit $fail
