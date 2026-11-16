#!/usr/bin/env bash
# SessionStart hook: say so when the enforcement this repo relies on is not there.
# Hooks fail silently when they are missing, so this is the only place that notices.
#
# 1. This checkout is behind origin/main and origin/main changed .claude/ (hooks, rules,
#    settings). Claude Code reads hooks from this checkout, not from the worktree you work
#    in, so stale hooks here mean no PR gate and no edit checks anywhere.
# 2. The shared skills or the pr-reviewer agent are not installed (e.g. a cloud container).
#
# No network call: compares against the last fetch. Never blocks the session.
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
msgs=()

if git rev-parse --git-dir >/dev/null 2>&1 && git rev-parse -q --verify origin/main >/dev/null; then
  head=$(git rev-parse HEAD)
  main=$(git rev-parse origin/main)
  if [ "$head" != "$main" ] && git merge-base --is-ancestor "$head" "$main" &&
    ! git diff --quiet "$head" "$main" -- .claude; then
    msgs+=("Hooks and rules in this checkout are behind origin/main (.claude/ changed). Claude Code reads them from here, so the PR gate and edit checks are stale: run git pull --ff-only, then restart the session.")
  fi
fi

missing=""
[ -f "$claude_dir/skills/lean-flutter-ui/SKILL.md" ] || missing="skills"
[ -f "$claude_dir/agents/pr-reviewer.md" ] || missing="${missing:+$missing and the }pr-reviewer agent"
if [ -n "$missing" ]; then
  msgs+=("Shared $missing not installed in $claude_dir. Install: git clone --depth 1 https://github.com/martin-dehlan/skills ~/skills && bash ~/skills/install.sh --clone, then restart the session.")
fi

[ ${#msgs[@]} -eq 0 ] && exit 0
python3 -c '
import json, sys
text = "\n".join(sys.argv[1:])
print(json.dumps({"systemMessage": text,
                  "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}}))
' "${msgs[@]}"
exit 0
