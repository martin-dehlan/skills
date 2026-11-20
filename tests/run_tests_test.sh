#!/usr/bin/env bash
# Fixture test for run_tests.sh with a fake `flutter`. Run: bash tests/run_tests_test.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
R="$ROOT/skills/flutter-feature-stack/scripts/run_tests.sh"
app=$(mktemp -d); trap 'rm -rf "$app"' EXIT; cd "$app" || exit 1
mkdir bin
fail=0
ok() { if "${@:2}" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
no() { if "${@:2}" >/dev/null 2>&1; then echo "FAIL $1"; fail=1; else echo "ok   $1"; fi; }
fake() { printf '#!/usr/bin/env bash\n%s\n' "$1" > bin/flutter; chmod +x bin/flutter; }
run() { PATH="$app/bin:$PATH" STALL="${STALL:-180}" bash "$R"; }

fake 'echo "00:01 +3: All tests passed!"; echo "tmp=$TMPDIR" >&2'
ok "a green run exits 0"                       run
ok "it logs to build/test.log"                 grep -q "All tests passed" build/test.log
ok "it runs with its own TMPDIR"               grep -q "tmp=.*run_tests\." build/test.log

fake 'echo "00:01 +1 -1: a_test.dart: x [E]"; exit 1'
no "a red run exits non-zero"                  run
ok "it lists the failing test"                 bash -c "PATH='$app/bin:$PATH' bash '$R' | grep -q 'a_test.dart: x'"

fake 'echo start; sleep 60'
STALL=10 run >/dev/null 2>&1; code=$?
ok "a silent run is stopped as hung (124)"     test "$code" -eq 124
no "the hung fake is gone"                     pgrep -f "$app/bin/flutter"

PATH="$app/bin:$PATH" bash "$R" >/dev/null 2>&1 & s=$!
sleep 2; kill -TERM "$s"; wait "$s"; code=$?
ok "TERM to the script exits 130"              test "$code" -eq 130
no "and leaves no orphan behind"               pgrep -f "$app/bin/flutter"
no "and releases the lock"                     test -d build/.run_tests.lock

sleep 60 & holder=$!
mkdir build/.run_tests.lock; echo "$holder" > build/.run_tests.lock/pid
WAIT_MAX=5 run >/dev/null 2>&1; code=$?
ok "a held lock makes it wait, then give up (125)" test "$code" -eq 125
ok "it leaves someone else's lock alone"       test -d build/.run_tests.lock
kill "$holder"; wait "$holder" 2>/dev/null
fake 'echo "00:01 +1: All tests passed!"'
ok "a stale lock (owner gone) is taken over"   run
exit $fail
