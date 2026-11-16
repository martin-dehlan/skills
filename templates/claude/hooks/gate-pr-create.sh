#!/usr/bin/env bash
# PreToolUse (Bash, if Bash(gh pr create*)): block until pr-reviewer has reviewed the commit
# that becomes the PR.
#
# Which commit: `--head <branch>` if given; else HEAD of the last `cd <dir>` before
# `gh pr create` in the command (a worktree); else HEAD of the working directory.
# Markers live in the common git dir, one file per reviewed commit, so the main checkout and
# every worktree see the same ones. The reviewer writes them:
#   d="$(git rev-parse --path-format=absolute --git-common-dir)/pr-reviews"; mkdir -p "$d"; touch "$d/$(git rev-parse HEAD)"
# The user can override for one call by prefixing the command with SKIP_PR_REVIEW=1.
cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
case "$cmd" in *"gh pr create"*) ;; *) exit 0 ;; esac
case "$cmd" in SKIP_PR_REVIEW=1*|*"&& SKIP_PR_REVIEW=1 gh pr create"*|*"; SKIP_PR_REVIEW=1 gh pr create"*) exit 0 ;; esac

# dir<TAB>head-branch, both possibly empty
target=$(python3 - "$cmd" <<'PY'
import os, re, sys
cmd = sys.argv[1]
pre, _, post = cmd.partition("gh pr create")
dirs = re.findall(r"(?:^|[;&|(]\s*)cd\s+(\"[^\"]+\"|'[^']+'|[^\s;&|)]+)", pre)
d = ""
if dirs:
    d = dirs[-1].strip("\"'")
    d = os.path.expanduser(d.replace("$HOME", os.path.expanduser("~")))
m = re.search(r"(?:--head|-H)[=\s]+(\"[^\"]+\"|'[^']+'|[^\s;&|)]+)", post)
head = m.group(1).strip("\"'").split(":")[-1] if m else ""
print(f"{d}\t{head}")
PY
)
dir=${target%%$'\t'*}
branch=${target#*$'\t'}
[ -n "$dir" ] || dir=.

deny() {
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$1"
  exit 0
}

[ -d "$dir" ] || deny "PR gate: cannot find the checkout '$dir' named by cd in the command. Run gh pr create from the worktree of the branch."
sha=$(git -C "$dir" rev-parse --verify -q "${branch:-HEAD}^{commit}" 2>/dev/null) ||
  deny "PR gate: cannot resolve '${branch:-HEAD}' in $dir. Push the branch from its worktree and run gh pr create there."
common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$common" ] && [ -f "$common/pr-reviews/$sha" ] && exit 0
# markers written by the reviewer before markers moved to the common dir
legacy=$(git -C "$dir" rev-parse --path-format=absolute --git-path pr-reviewed 2>/dev/null)
[ -f "$legacy" ] && [ "$(cat "$legacy")" = "$sha" ] && exit 0

deny "No pr-reviewer run for ${branch:-HEAD} (${sha:0:8}) in $dir. Run the pr-reviewer agent on that checkout first; it records the review. Override only if the user says so: prefix the command with SKIP_PR_REVIEW=1."
