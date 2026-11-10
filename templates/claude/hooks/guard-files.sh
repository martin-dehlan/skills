#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit): refuse edits to generated files and real env files.
# Reads the tool call JSON on stdin; prints a deny decision with the reason, or nothing.
file=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
reason=""
case "$file" in
  *.g.dart|*.freezed.dart|*.gr.dart)
    reason="Generated file. Change the source (@riverpod, @freezed, Drift table) and run: dart run build_runner build" ;;
  *.env.example|*.env.*.example|*.example) ;;
  */.env|*/.env.*|.env|.env.*)
    reason="Real env file (git-ignored, holds secrets). Edit the .example file; the user fills the real one." ;;
esac
if [ -n "$reason" ]; then
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$reason"
fi
exit 0
