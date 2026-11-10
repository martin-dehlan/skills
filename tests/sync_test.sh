#!/usr/bin/env bash
# Fixture test for sync.sh. Run: bash tests/sync_test.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
app=$(mktemp -d); trap 'rm -rf "$app"' EXIT
fail=0
t() { if "${@:2}" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
n() { if "${@:2}" >/dev/null 2>&1; then echo "FAIL $1"; fail=1; else echo "ok   $1"; fi; }

n "check fails on an empty app"           "$ROOT/sync.sh" --check "$app"
t "sync copies"                           "$ROOT/sync.sh" "$app"
t "check is green after sync"             "$ROOT/sync.sh" --check "$app"
t "stamp is on line 2 of a script"        grep -q '^# skills@' <(sed -n 2p "$app/scripts/check_ui_rules.sh")
t "executable bit survives"               test -x "$app/scripts/check_ui_rules.sh"
echo "# local edit" >> "$app/scripts/check_secrets.sh"
n "check fails on a modified script"      "$ROOT/sync.sh" --check "$app"
t "sync repairs it"                       "$ROOT/sync.sh" "$app"
t "check is green again"                  "$ROOT/sync.sh" --check "$app"
echo "# mine" > "$app/.gitleaks.toml"
t "sync keeps an app-owned seed file"     "$ROOT/sync.sh" "$app"
t "seed file untouched"                   grep -q '^# mine' "$app/.gitleaks.toml"
rm "$app/scripts/check_login_config.sh"
n "check fails on a missing script"       "$ROOT/sync.sh" --check "$app"
exit $fail
