#!/usr/bin/env bash
# Fixture test for skills/lean-flutter-ui/scripts/check_ui_rules.sh.
#   bash tests/check_ui_rules_test.sh
set -uo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/skills/lean-flutter-ui/scripts/check_ui_rules.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0
check() { if [ "$2" = "$3" ]; then echo "  ok    $1"; else echo "  FAIL  $1 (expected $3, got $2)"; fails=$((fails + 1)); fi; }

cd "$tmp" && git init -q -b main . && git commit -q --allow-empty -m init && git checkout -q -b feat
mkdir -p lib/x lib/common/theme
cat > lib/x/bad.dart <<'DART'
final a = SizedBox(height: 12);
final b = EdgeInsets.only(left: 8);
final c = TextStyle(fontSize: 14);
final d = Colors.red;
final e = Color(0xFF000000);
final f = Color.fromARGB(255, 1, 2, 3);
final g = LinearGradient(colors: []);
final h = BackdropFilter(filter: x);
final i = ImageFilter.blur(sigmaX: 3, sigmaY: 3);
final j = BoxShadow(blurRadius: 40);
final k = Material(elevation: 8);
final l = BorderRadius.circular(24);
final m = Gap(16);
final n = MediaQuery.of(context).size;
final o = Text('Launch 🚀');
Widget _buildHeader() => x;
void p() { print('x'); }
DART
cat > lib/x/clean.dart <<'DART'
// Colors.red in a comment is fine, so is SizedBox(height: 12).
final a = SizedBox(height: context.m);
final b = Colors.transparent;
final c = Colors.black; // ui-rules-ok: the Apple button must be black
final d = BorderRadius.circular(context.cardRadius);
final e = Material(elevation: 1);
final f = BoxShadow(blurRadius: 8);
final g = MediaQuery.sizeOf(context);
void h() { debugPrint('x'); }
final i = 'https://example.com'; // a URL is not a comment
DART
echo 'final t = Color(0xFF112233);' > lib/common/theme/app_theme.dart
git add -A && git commit -q -m fixtures

out=$(bash "$script" main 2>&1); code=$?
check "violations exit 1" "$code" 1
check "every bad line reported" "$(echo "$out" | grep -c 'lib/x/bad.dart:')" 17
check "clean file not reported" "$(echo "$out" | grep -c 'lib/x/clean.dart')" 0
check "theme folder excluded" "$(echo "$out" | grep -c 'app_theme.dart')" 0

bash "$script" no-such-ref >/dev/null 2>&1; check "missing base exits 2" "$?" 2

bash "$script" --file lib/x/clean.dart >/dev/null 2>&1; check "--file clean exits 0" "$?" 0
out=$(bash "$script" --file lib/x/bad.dart 2>&1); check "--file bad exits 1" "$?" 1
check "--file reports every line" "$(echo "$out" | grep -c 'lib/x/bad.dart:')" 17
bash "$script" --file lib/common/theme/app_theme.dart >/dev/null 2>&1; check "--file skips the theme" "$?" 0

git checkout -q main && git checkout -q -b empty
bash "$script" main >/dev/null 2>&1; check "no diff exits 0" "$?" 0

[ "$fails" = 0 ] && echo "check_ui_rules: all tests passed" || { echo "check_ui_rules: $fails failed"; exit 1; }
