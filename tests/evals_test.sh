#!/usr/bin/env bash
# The eval runner scores answers with a fake `claude`. Run: bash tests/evals_test.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
bin=$(mktemp -d); trap 'rm -rf "$bin" "$ROOT"/evals/results/*-test*' EXIT
printf '#!/usr/bin/env bash\necho "use a grant and enable row level security; toUtc; login_failed; skeleton retry"\n' > "$bin/claude"; chmod +x "$bin/claude"
out=$(PATH="$bin:$PATH" bash "$ROOT/evals/run.sh" --skill supabase-app-backend 2>&1)
echo "$out" | grep -q "PASS.*notes table" && echo "ok   matching answer passes" || { echo "FAIL pass case"; echo "$out"; exit 1; }
echo "$out" | grep -q "FAIL.*bucket fails" && echo "ok   non-matching answer fails" || { echo "FAIL fail case"; exit 1; }
rm -f "$ROOT"/evals/results/*-on.tsv
