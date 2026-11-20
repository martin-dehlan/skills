#!/usr/bin/env bash
# flutter test that survives other agent sessions on the same machine.
#
# Several sessions running `flutter test` at once share Flutter's startup lock
# and the flutter_tools temp folder: a second run sits silently before
# compiling, or its testers die with SIGTERM / PathNotFoundException
# (flutter_test_listener). This script
#   1. waits while another flutter test run is going (up to WAIT_MAX seconds),
#   2. gives the run its own TMPDIR,
#   3. logs to build/test.log with the expanded reporter (progress visible),
#   4. stops its own run after STALL seconds without a new log line (hung),
#   5. prints the summary and the failing tests.
#
# Usage: bash scripts/run_tests.sh [flutter test args...]
# Exit: flutter's exit code; 124 when the run hung; 125 when the wait timed out.
set -u

WAIT_MAX="${WAIT_MAX:-900}"
STALL="${STALL:-180}"
LOG="build/test.log"
mkdir -p build

# flutter test runs in this project directory (another session, or an orphan
# of an earlier run whose shell was killed: it keeps writing into build/).
# Runs in other projects are left alone; the own TMPDIR keeps them apart.
others() {
  local p
  for p in $(pgrep -f 'flutter_tools.snapshot test' 2>/dev/null); do
    [ "$(lsof -a -p "$p" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')" = "$PWD" ] && echo "$p"
  done
}

# Only this run's processes: flutter → dart → flutter_tester children.
killtree() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null); do killtree "$child"; done
  kill -TERM "$1" 2>/dev/null
}

waited=0
while [ -n "$(others)" ]; do
  if [ "$waited" -eq 0 ]; then
    echo "run_tests: another flutter test run is going (pids $(others | tr '\n' ' ')), waiting..."
  fi
  if [ "$waited" -ge "$WAIT_MAX" ]; then
    echo "run_tests: still busy after ${WAIT_MAX}s, giving up (never kill another session's run)"
    exit 125
  fi
  sleep 5
  waited=$((waited + 5))
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/run_tests.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

TMPDIR="$tmp" flutter test --reporter expanded --timeout 60s "$@" >"$LOG" 2>&1 &
pid=$!

last_size=-1
idle=0
while kill -0 "$pid" 2>/dev/null; do
  sleep 5
  size=$(wc -c <"$LOG" | tr -d ' ')
  if [ "$size" = "$last_size" ]; then
    idle=$((idle + 5))
  else
    idle=0
    last_size=$size
  fi
  if [ "$idle" -ge "$STALL" ]; then
    echo "run_tests: no output for ${STALL}s, stopping this run (pid $pid only)"
    killtree "$pid"
    tail -5 "$LOG"
    exit 124
  fi
done
wait "$pid"
code=$?

grep -E '\[E\]$' "$LOG" | sed -E 's/^[0-9:]+ [+0-9 -]+: //' | sort -u | head -30
tail -1 "$LOG"
echo "run_tests: exit $code, full log in $LOG"
exit "$code"
