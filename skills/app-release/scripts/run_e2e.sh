#!/usr/bin/env bash
# run_e2e.sh: build, install and run the Maestro flows on one emulator or
# simulator, then print only what failed. Run from the app root.
#
#   bash scripts/run_e2e.sh ios                       # every flow in e2e/
#   bash scripts/run_e2e.sh android --tags auth       # only flows tagged auth
#   bash scripts/run_e2e.sh ios --no-build build/e2e/scratch.yaml
#
# Device: the booted simulator or the connected emulator. If none is running,
# it boots $E2E_SIM (iOS, a simulator name, default the newest iPhone) or
# $E2E_AVD (Android, default "e2e"; from the "logged-in" snapshot if it exists).
# Build: Android release APK (what ships); iOS debug simulator build (release
# builds do not run on a simulator). Extra flags go in $FLUTTER_BUILD_ARGS.
# Variables: every E2E_* variable (from .env.e2e, git-ignored) reaches Maestro
# as -e NAME=value.
# Output: build/e2e/report.xml, build/e2e/maestro.log, and screenshots plus
# command logs of every run under build/e2e/out/.
set -uo pipefail

usage="usage: $0 ios|android [--tags a,b] [--no-build] [flow-or-dir ...]"
platform="${1:-}"
case "$platform" in ios|android) shift ;; *) echo "$usage"; exit 2 ;; esac

tags=""; build=1; flows=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tags) tags="${2:?--tags needs a value}"; shift 2 ;;
    --no-build) build=0; shift ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) flows+=("$1"); shift ;;
  esac
done
[ ${#flows[@]} -eq 0 ] && flows=(e2e/)

export PATH="$HOME/.maestro/bin:$PATH"
command -v maestro >/dev/null || { echo "maestro not installed (see device-testing.md, Mac setup)"; exit 1; }

if [ -f .env.e2e ]; then set -a; . ./.env.e2e; set +a; fi

# Runs a command with a time limit (macOS has no `timeout`).
within() { local s=$1; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }

# A wedged emulator still shows as "device" in `adb devices`, and Maestro then
# hangs without output, on iOS runs too. Fail fast instead.
if command -v adb >/dev/null; then
  for d in $(within 10 adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}'); do
    if [ "$(within 10 adb -s "$d" shell echo ok 2>/dev/null | tr -d '\r')" != ok ]; then
      echo "Android device $d does not answer (adb shell hangs). Maestro would hang too."
      echo "Another session may be using it. Free or restart it, then run again."
      exit 1
    fi
  done
fi

# --- device ---------------------------------------------------------------
device=""
if [ "$platform" = ios ]; then
  device=$(xcrun simctl list devices booted | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')
  if [ -z "$device" ]; then
    if [ -n "${E2E_SIM:-}" ]; then
      line=$(xcrun simctl list devices available | grep -F "    ${E2E_SIM} (" | tail -1)
    else
      line=$(xcrun simctl list devices available | grep -E '^ +iPhone' | tail -1)
    fi
    device=$(echo "$line" | grep -Eo '\([0-9A-F-]{36}\)' | tr -d '()')
    [ -n "$device" ] || { echo "no iOS simulator found (E2E_SIM=${E2E_SIM:-})"; exit 1; }
    echo "booting simulator: $(echo "$line" | sed -E 's/ \(.*//; s/^ +//')"
    xcrun simctl boot "$device" && xcrun simctl bootstatus "$device" -b >/dev/null || exit 1
    open -a Simulator
  fi
else
  first_android() { adb devices | awk 'NR>1 && $2=="device" {print $1; exit}'; }
  device=$(first_android)
  if [ -z "$device" ]; then
    sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
    avd="${E2E_AVD:-e2e}"
    args=(-avd "$avd" -no-boot-anim)
    [ -d "$HOME/.android/avd/$avd.avd/snapshots/logged-in" ] && args+=(-snapshot logged-in)
    echo "booting emulator: $avd ${args[*]:3}"
    nohup "$sdk/emulator/emulator" "${args[@]}" >/dev/null 2>&1 &
    adb wait-for-device
    for _ in $(seq 90); do
      [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
      sleep 2
    done
    device=$(first_android)
    [ -n "$device" ] || { echo "emulator did not boot within 3 minutes"; exit 1; }
  fi
fi
echo "device: $platform $device"

# --- build and install -----------------------------------------------------
if [ "$build" = 1 ]; then
  # shellcheck disable=SC2086  # FLUTTER_BUILD_ARGS is a list of flags
  if [ "$platform" = ios ]; then
    flutter build ios --simulator --debug ${FLUTTER_BUILD_ARGS:-} || exit 1
    xcrun simctl install "$device" build/ios/iphonesimulator/Runner.app || exit 1
  else
    flutter build apk --release ${FLUTTER_BUILD_ARGS:-} || exit 1
    adb -s "$device" install -r build/app/outputs/flutter-apk/app-release.apk || exit 1
  fi
fi

# --- run ---------------------------------------------------------------------
out=build/e2e
rm -rf "$out/out"; mkdir -p "$out/out"
extra=()
[ -n "$tags" ] && extra+=(--include-tags "$tags")
for v in $(env | grep -oE '^E2E_[A-Z0-9_]+' | sort -u); do extra+=(-e "$v=${!v}"); done

echo "running: ${flows[*]}${tags:+ (tags: $tags)}"
maestro test --device "$device" "${flows[@]}" ${extra[@]+"${extra[@]}"} \
  --format junit --output "$out/report.xml" --test-output-dir "$out/out" \
  >"$out/maestro.log" 2>&1
status=$?

# --- summary -----------------------------------------------------------------
if [ ! -s "$out/report.xml" ]; then
  echo "no report: maestro stopped before running a flow. Last lines of $out/maestro.log:"
  tail -20 "$out/maestro.log"
  exit 1
fi
python3 -I - "$out/report.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
cases = list(ET.parse(sys.argv[1]).getroot().iter("testcase"))
failed = []
for c in cases:
    f = c.find("failure")
    if f is None:
        f = c.find("error")
    if f is not None:
        msg = (f.get("message") or f.text or "").strip().splitlines()
        failed.append((c.get("name"), msg[0] if msg else ""))
print(f"passed {len(cases) - len(failed)}/{len(cases)}")
for name, msg in failed:
    print(f"  FAIL  {name}: {msg}")
PY
[ "$status" = 0 ] || echo "screenshots and step logs: $out/out/ (full log: $out/maestro.log)"
exit "$status"
