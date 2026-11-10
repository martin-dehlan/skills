#!/usr/bin/env bash
# Fixture test for check_layers.sh and check_file_sizes.sh. Run: bash tests/layer_size_test.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
L="$ROOT/skills/flutter-feature-stack/scripts/check_layers.sh"
S="$ROOT/skills/flutter-feature-stack/scripts/check_file_sizes.sh"
app=$(mktemp -d); trap 'rm -rf "$app"' EXIT; cd "$app"
git init -q -b main; git config user.email t@t; git config user.name t
mkdir -p lib/features/a/presentation lib/features/a/domain lib/features/a/controller
echo "class A {}" > lib/features/a/domain/a.entity.dart
echo "import 'package:flutter/material.dart';" > lib/features/a/presentation/a.screen.dart
git add -A; git commit -qm base
fail=0
ok() { if "${@:2}" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
no() { if "${@:2}" >/dev/null 2>&1; then echo "FAIL $1"; fail=1; else echo "ok   $1"; fi; }

git checkout -qb t1
echo "import 'package:supabase_flutter/supabase_flutter.dart';" >> lib/features/a/presentation/a.screen.dart
git commit -qam x
no "widget importing supabase fails"          bash "$L" main
ok "same import with layers-ok passes"        bash -c "sed -i.bak \"s#supabase_flutter.dart';#supabase_flutter.dart'; // layers-ok: auth button#\" lib/features/a/presentation/a.screen.dart && git commit -qam y && bash '$L' main"
git checkout -q main; git checkout -qb t2
echo "import 'package:flutter/material.dart';" >> lib/features/a/domain/a.entity.dart; git commit -qam x
no "domain importing flutter fails"           bash "$L" main
ok "--file mode flags it too"                 bash -c "! bash '$L' --file lib/features/a/domain/a.entity.dart"
no "missing base exits non-zero"              bash "$L" nope
git checkout -q main
ok "old violation without a diff passes"      bash "$L" main

seq 1 320 | sed 's/.*/\/\/ x/' > lib/features/a/presentation/big.widget.dart; git add -A; git commit -qm big
no "new file over the limit fails"            bash "$S"
bash "$S" --update >/dev/null
ok "baseline accepts it"                      bash "$S"
echo "// more" >> lib/features/a/presentation/big.widget.dart
no "growing a baselined file fails"           bash "$S"
exit $fail
