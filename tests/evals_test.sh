#!/usr/bin/env bash
# The eval runner scores answers with a fake `claude`. Run: bash tests/evals_test.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
bin=$(mktemp -d); res=$(mktemp -d); trap 'rm -rf "$bin" "$res"' EXIT
fail=0
# The fake answers with its fixed text plus whatever it can read on stdin.
printf '#!/usr/bin/env bash\necho "use a grant and enable row level security; toUtc; login_failed; skeleton retry"\ncat\n' > "$bin/claude"; chmod +x "$bin/claude"
out=$(PATH="$bin:$PATH" EVAL_RESULTS_DIR="$res" bash "$ROOT/evals/run.sh" --skill supabase-app-backend 2>&1)
echo "$out" | grep -q "PASS.*notes table" && echo "ok   matching answer passes" || { echo "FAIL pass case"; echo "$out"; fail=1; }
echo "$out" | grep -q "FAIL.*bucket fails" && echo "ok   non-matching answer fails" || { echo "FAIL fail case"; fail=1; }
want=$(awk -F'\t' '$1=="supabase-app-backend"' "$ROOT/evals/prompts.tsv" | wc -l | tr -d ' ')
got=$(grep -c '^supabase-app-backend' "$res"/*-on.tsv)
[ "$got" = "$want" ] && echo "ok   claude does not eat the next prompts from stdin" || { echo "FAIL ran $got of $want prompts"; fail=1; }
f=$(awk -F'\t' 'NR==1{print $4}' "$res"/*-on.tsv)
grep -q "row level security" "$f" 2>/dev/null && echo "ok   the answer is saved next to the verdict" || { echo "FAIL answer not saved ($f)"; fail=1; }

# Every pattern must compile as a grep -E regex; a bad one would score as a silent pass.
bad=0
while IFS=$'\t' read -r skill _ expect forbid; do
  case "$skill" in ''|\#*) continue ;; esac
  for re in "$expect" "$forbid"; do
    [ -n "$re" ] || continue
    printf '' | grep -Eq -- "$re" 2>/dev/null; [ $? -le 1 ] || { echo "FAIL $skill: pattern does not compile: $re"; bad=1; }
  done
done < "$ROOT/evals/prompts.tsv"
[ $bad -eq 0 ] && echo "ok   every pattern compiles" || fail=1

printf '#!/usr/bin/env bash\necho x\n' > "$bin/claude"
printf 'demo\tp\t(?!x)\t\n' > "$res/p.tsv"
sed "s#\"\$here/prompts.tsv\"#\"$res/p.tsv\"#" "$ROOT/evals/run.sh" > "$res/run.sh"
out=$(PATH="$bin:$PATH" EVAL_RESULTS_DIR="$res" bash "$res/run.sh" 2>&1)
echo "$out" | grep -q "^demo	ERROR" && echo "ok   a broken pattern is an ERROR" || { echo "FAIL broken pattern: $out"; fail=1; }
exit $fail
