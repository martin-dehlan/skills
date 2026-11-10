#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): run the UI, layer and size checks on the Dart file
# Claude just wrote and hand violations back as context in the same turn. Never blocks.
file=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
case "$file" in *.dart) ;; *) exit 0 ;; esac
case "$file" in *.g.dart|*.freezed.dart) exit 0 ;; esac
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] && [ -f "$file" ] || exit 0
cd "$root" || exit 0
out=""
for c in check_ui_rules.sh check_layers.sh check_file_sizes.sh; do
  [ -x "scripts/$c" ] || continue
  r=$(bash "scripts/$c" --file "$file" 2>&1) || out="$out$r"$'\n'
done
if [ -n "$out" ]; then
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Rule violations in the file you just wrote. Fix them now:\n"+sys.argv[1]}}))' "$out"
fi
exit 0
