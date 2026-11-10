#!/usr/bin/env bash
# Fixture test for skills/app-release/scripts/check_login_config.sh.
set -uo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/skills/app-release/scripts/check_login_config.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0
check() { if [ "$2" = "$3" ]; then echo "  ok    $1"; else echo "  FAIL  $1 (expected $3, got $2)"; fails=$((fails + 1)); fi; }
run() { (cd "$tmp" && HOME="$tmp/home" bash "$script" "$@" 2>&1); }

mkdir -p "$tmp/home" "$tmp/ios/Runner" "$tmp/android/app/src/main" "$tmp/lib"
printf 'dependencies:\n  google_sign_in: ^7.0.0\n' > "$tmp/pubspec.yaml"
cat > "$tmp/ios/Runner/Info.plist" <<'PL'
<plist><dict><key>CFBundleURLTypes</key><array><dict><key>CFBundleURLSchemes</key><array>
<string>com.googleusercontent.apps.123-abc</string></array></dict></array></dict></plist>
PL
cat > "$tmp/lib/google.dart" <<'DART'
final g = GoogleSignIn.instance;
await g.initialize(serverClientId: 'x');
DART

run >/dev/null; check "no nonce fails" "$?" 1
cat > "$tmp/lib/google.dart" <<'DART'
final g = GoogleSignIn.instance;
await g.initialize(serverClientId: 'x', nonce: hashed);
DART
out=$(run); check "nonce passes the nonce check" "$(echo "$out" | grep -c 'passes a nonce')" 1
check "missing SHA-1 file warns without --strict" "$(run >/dev/null; echo $?)" 0
out=$(run --strict); code=$?
check "missing SHA-1 file fails with --strict" "$code" 1
check "strict message names the file" "$(echo "$out" | grep -c 'google-sha1.txt')" 1
printf 'AA:BB\nCC:DD\nEE:FF\n' > "$tmp/android/google-sha1.txt"
run --strict >/dev/null; check "three entries pass --strict" "$?" 0
printf 'AA:BB\n' > "$tmp/android/google-sha1.txt"
run --strict >/dev/null; check "one entry fails --strict" "$?" 1

[ "$fails" = 0 ] && echo "check_login_config: all tests passed" || { echo "check_login_config: $fails failed"; exit 1; }
