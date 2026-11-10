#!/usr/bin/env bash
# PreToolUse (Bash, if Bash(gh pr create*)): block until pr-reviewer has reviewed this HEAD.
# The reviewer writes the marker:  git rev-parse HEAD > "$(git rev-parse --git-path pr-reviewed)"
# The user can override for one call by prefixing the command with SKIP_PR_REVIEW=1.
cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
case "$cmd" in *"gh pr create"*) ;; *) exit 0 ;; esac
case "$cmd" in SKIP_PR_REVIEW=1*) exit 0 ;; esac
head=$(git rev-parse HEAD 2>/dev/null) || exit 0
marker=$(git rev-parse --git-path pr-reviewed 2>/dev/null)
if [ -f "$marker" ] && [ "$(cat "$marker")" = "$head" ]; then exit 0; fi
python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"No pr-reviewer run for the current HEAD ("+sys.argv[1][:8]+"). Run the pr-reviewer agent first; it records the review. Override only if the user says so: prefix the command with SKIP_PR_REVIEW=1."}}))' "$head"
exit 0
