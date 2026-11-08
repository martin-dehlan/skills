#!/usr/bin/env bash
# PostToolUse hook: formats the Dart file Claude just wrote or edited.
# Never blocks the session; formatting is checked again in CI.
file=$(python3 -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))' 2>/dev/null)
case "$file" in
  ""|*.g.dart|*.freezed.dart) ;;
  *.dart) dart format "$file" >/dev/null 2>&1 ;;
esac
exit 0
