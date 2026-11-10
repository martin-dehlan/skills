#!/usr/bin/env bash
# check_login_config.sh: catches the login breakages that are configuration,
# not code. Run from the app root before every release (and in CI).
#
#   bash scripts/check_login_config.sh            # warnings do not fail
#   bash scripts/check_login_config.sh --strict   # release and CI: a missing
#                                                 # SHA-1 list is a failure
#
# Checks only what the app uses (read from pubspec.yaml):
#   app_links          → engine deep linking switched off on iOS and Android
#   sign_in_with_apple → every iOS entitlements file has the Apple sign-in capability
#   google_sign_in     → the reversed iOS client ID registered as URL scheme
#   android signing    → debug + upload key SHA-1 listed in android/google-sha1.txt
#                        (the fingerprints registered in Google Cloud, one per line)
#   google_sign_in     → initialize() passes a nonce (Supabase rejects the token
#                        otherwise)
set -uo pipefail

strict=0; [ "${1:-}" = "--strict" ] && strict=1
fail=0; warn=0
ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; fail=1; }
note() { echo "  warn  $1"; warn=1; }
# A check that cannot run without its input: a failure in --strict, else a warning.
need() { if [ "$strict" = 1 ]; then bad "$1"; else note "$1"; fi; }
uses() { grep -qE "^\s+$1:" pubspec.yaml; }

plist=ios/Runner/Info.plist
manifest=android/app/src/main/AndroidManifest.xml

echo "Login configuration"

if uses app_links; then
  if grep -A1 '<key>FlutterDeepLinkingEnabled</key>' "$plist" 2>/dev/null | grep -q '<false/>'; then
    ok "iOS: FlutterDeepLinkingEnabled = false"
  else
    bad "iOS: set FlutterDeepLinkingEnabled to <false/> in $plist (app_links owns deep links)"
  fi
  if grep -A1 'flutter_deeplinking_enabled' "$manifest" 2>/dev/null | grep -q 'android:value="false"'; then
    ok "Android: flutter_deeplinking_enabled = false"
  else
    bad "Android: add <meta-data android:name=\"flutter_deeplinking_enabled\" android:value=\"false\"/> to $manifest"
  fi
fi

if uses sign_in_with_apple; then
  found=0
  for e in ios/Runner/*.entitlements; do
    [ -f "$e" ] || continue
    found=1
    if grep -q 'com.apple.developer.applesignin' "$e"; then ok "iOS: Apple sign-in capability in $(basename "$e")"
    else bad "iOS: $(basename "$e") lacks com.apple.developer.applesignin"; fi
  done
  [ "$found" = 1 ] || bad "iOS: no .entitlements file in ios/Runner"
fi

if uses google_sign_in; then
  client=$(grep -A1 '<key>GIDClientID</key>' "$plist" 2>/dev/null | grep -oE '[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com' | head -1)
  if [ -z "$client" ]; then
    # No GIDClientID: the iOS client ID is passed in code (clientId:), but the
    # reversed client ID must still be a registered URL scheme.
    if grep -qE '<string>com\.googleusercontent\.apps\.[^<]+</string>' "$plist"; then
      ok "iOS: Google URL scheme registered (client ID passed in code; keep the two in sync)"
    else
      bad "iOS: no com.googleusercontent.apps.* URL scheme in $plist"
    fi
  else
    reversed="com.googleusercontent.apps.${client%.apps.googleusercontent.com}"
    if grep -q "<string>$reversed</string>" "$plist"; then ok "iOS: URL scheme matches GIDClientID"
    else bad "iOS: add URL scheme $reversed to CFBundleURLSchemes"; fi
  fi

  allow=android/google-sha1.txt
  if [ ! -f "$allow" ]; then
    need "Android: create $allow with the SHA-1s registered in Google Cloud (debug, upload, Play App Signing); without it the SHA-1 check does not run"
  else
    listed=$(grep -vE '^\s*(#|$)' "$allow" | tr 'a-f' 'A-F' | tr -d ' ')
    [ "$(echo "$listed" | grep -c .)" -ge 3 ] || need "Android: $allow has fewer than 3 entries (debug, upload, Play App Signing)"
    # The password goes through the environment, not the command line (ps, shell history).
    sha1_of() { KEYSTORE_PASS="$3" keytool -list -v -keystore "$1" -alias "$2" -storepass:env KEYSTORE_PASS 2>/dev/null | grep -E '^\s*SHA1:' | awk '{print $2}' | tr 'a-f' 'A-F'; }
    check_key() {  # check_key <label> <keystore> <alias> <password>
      [ -f "$2" ] || { note "Android: $1 keystore not found ($2), skipped"; return; }
      command -v keytool >/dev/null || { note "Android: keytool not on PATH, skipped $1 key"; return; }
      local sha; sha=$(sha1_of "$2" "$3" "$4")
      if [ -z "$sha" ]; then note "Android: could not read the $1 key"
      elif echo "$listed" | grep -qx "$sha"; then ok "Android: $1 key SHA-1 is registered"
      else bad "Android: $1 key SHA-1 $sha is not in $allow, so Google sign-in fails in that build"; fi
    }
    check_key debug "$HOME/.android/debug.keystore" androiddebugkey android
    props=android/key.properties
    if [ -f "$props" ]; then
      prop() { grep -E "^$1=" "$props" | head -1 | cut -d= -f2-; }
      store=$(prop storeFile); case "$store" in /*) ;; *) store="android/app/$store" ;; esac
      check_key upload "$store" "$(prop keyAlias)" "$(prop storePassword)"
    else
      note "Android: $props missing, upload key not checked"
    fi
  fi

  # Without a nonce GoTrue rejects the Google token.
  # Files that use GoogleSignIn.instance (it is often held in a local variable first).
  init_files=$(grep -rlE 'GoogleSignIn\.instance' lib 2>/dev/null | xargs grep -lE '\.initialize\(' 2>/dev/null || true)
  if [ -z "$init_files" ]; then
    note "Google: no GoogleSignIn initialize( call found in lib/, nonce not checked"
  elif grep -A8 -hE '\.initialize\(' $init_files | grep -q 'nonce:'; then
    ok "Google: initialize() passes a nonce"
  else
    bad "Google: initialize() passes no nonce (google_sign_in 7 accepts nonce:; see the supabase-app-backend skill)"
  fi
fi

echo
if [ "$fail" = 1 ]; then echo "Login configuration: FAILED"; exit 1; fi
[ "$warn" = 1 ] && echo "Login configuration: OK with warnings" || echo "Login configuration: OK"
