#!/usr/bin/env bash
# flutter test that survives other agent sessions on the same machine.
#
# Several sessions running `flutter test` at once share the flutter_tools temp
# folder, and a killed shell leaves Flutter's dart process running and writing
# on. Runs then hang silently or die with SIGTERM / PathNotFoundException
# (flutter_test_listener). This script
#   1. takes a lock in build/ and waits while another flutter test run is going
#      in this project (a session, or an orphan of an earlier run), up to
#      WAIT_MAX seconds; runs in other projects are left alone,
#   2. gives the run its own TMPDIR,
#   3. logs to build/test.log with the expanded reporter (progress visible) and
#      `--timeout 60s` per test (a later --timeout in the arguments wins),
#   4. stops its own run after STALL seconds without a new log line (hung), and
#      on Ctrl-C / TERM, so it never leaves an orphan behind,
#   5. prints the failing tests and the summary.
#
# A full suite takes minutes and STALL is 180 s: agents run it in the
# background or with a long tool timeout, never under a 120 s default.
#
# Usage: bash scripts/run_tests.sh [flutter test args...]
# Exit: flutter's exit code; 124 hung; 125 still busy after WAIT_MAX; 130 stopped.
set -u

WAIT_MAX="${WAIT_MAX:-900}"
STALL="${STALL:-180}"
LOG="build/test.log"
LOCK="build/.run_tests.lock"
HERE="$(pwd -P)"
mkdir -p build

# flutter test runs whose working directory is this project. lsof prints the
# resolved path, hence `pwd -P`. Global flags may sit between the snapshot and
# `test` (flutter -v test).
others() {
  local p
  for p in $(pgrep -f 'flutter_tools\.snapshot.* test( |$)' 2>/dev/null); do
    [ "$(lsof -a -p "$p" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')" = "$HERE" ] && echo "$p"
  done
}

# Only this run's processes: pause the parent so it starts nothing new, TERM
# the tree, then KILL what is left (a blocked dart isolate ignores TERM).
tree() {
  local c
  echo "$1"
  for c in $(pgrep -P "$1" 2>/dev/null); do tree "$c"; done
}
killtree() {
  local pids
  kill -STOP "$1" 2>/dev/null
  pids="$(tree "$1")"
  kill -TERM $pids 2>/dev/null
  kill -CONT "$1" 2>/dev/null
  sleep 5
  kill -KILL $pids 2>/dev/null
}

# The lock closes the gap between "nobody is running" and "I start": two
# sessions starting at once would otherwise both run into one log.
lock_free() {
  if mkdir "$LOCK" 2>/dev/null; then echo $$ >"$LOCK/pid"; return 0; fi
  local holder
  holder="$(cat "$LOCK/pid" 2>/dev/null)"
  if [ -z "$holder" ] || ! kill -0 "$holder" 2>/dev/null; then
    rm -rf "$LOCK"   # stale: its owner is gone
    mkdir "$LOCK" 2>/dev/null && echo $$ >"$LOCK/pid" && return 0
  fi
  return 1
}

pid=""
tmp=""
cleanup() {
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && killtree "$pid"
  [ -n "$tmp" ] && rm -rf "$tmp"
  [ "$(cat "$LOCK/pid" 2>/dev/null)" = "$$" ] && rm -rf "$LOCK"
}
trap cleanup EXIT
trap 'echo "run_tests: stopped"; exit 130' INT TERM HUP

waited=0
until lock_free && [ -z "$(others)" ]; do
  [ "$(cat "$LOCK/pid" 2>/dev/null)" = "$$" ] && rm -rf "$LOCK"
  [ "$waited" -eq 0 ] && echo "run_tests: another flutter test run is going in this project, waiting..."
  if [ "$waited" -ge "$WAIT_MAX" ]; then
    echo "run_tests: still busy after ${WAIT_MAX}s. Runs here (stop only your own):"
    o="$(others | tr '\n' ',' | sed 's/,$//')"
    [ -n "$o" ] && ps -o pid,etime,command -p "$o"
    echo "lock: $LOCK (pid $(cat "$LOCK/pid" 2>/dev/null))"
    exit 125
  fi
  sleep 5
  waited=$((waited + 5))
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/run_tests.XXXXXX")"
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
    pid=""
    tail -5 "$LOG"
    exit 124
  fi
done
wait "$pid"
code=$?
pid=""

grep -E '\[E\]$' "$LOG" | sed -E 's/^[0-9:]+ [-+~0-9 ]+: //' | sort -u | head -30
tail -1 "$LOG"
echo "run_tests: exit $code, full log in $LOG"
exit "$code"
