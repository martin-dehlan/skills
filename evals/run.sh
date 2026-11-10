#!/usr/bin/env bash
# Run the eval prompts through Claude Code and score the answers against evals/prompts.tsv.
#   evals/run.sh [--skill <name>] [--off]     (--off uses an empty config dir: the baseline without skills)
# Needs: `claude` on PATH, logged in. Costs tokens: 30 prompts per pass. Output: one line per
# prompt (PASS/FAIL) and a total, plus results in evals/results/<date>-<on|off>.tsv.
# Env: EVAL_OFF_CONFIG_DIR (default: a temp dir) for --off; EVAL_MODEL (default: the CLI default).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
only=""; mode=on
while [ $# -gt 0 ]; do case "$1" in --skill) only="$2"; shift 2 ;; --off) mode=off; shift ;; *) echo "unknown arg $1" >&2; exit 2 ;; esac; done
command -v claude >/dev/null || { echo "claude not found" >&2; exit 2; }
mkdir -p "$here/results"; out="$here/results/$(date +%F)-$mode.tsv"; : > "$out"
if [ "$mode" = off ]; then export CLAUDE_CONFIG_DIR="${EVAL_OFF_CONFIG_DIR:-$(mktemp -d)}"; fi
model=(); [ -n "${EVAL_MODEL:-}" ] && model=(--model "$EVAL_MODEL")
pass=0; total=0
while IFS=$'\t' read -r skill prompt expect forbid; do
  case "$skill" in ''|\#*) continue ;; esac
  [ -n "$only" ] && [ "$skill" != "$only" ] && continue
  answer=$(cd "$(mktemp -d)" && claude -p "$prompt" ${model[@]+"${model[@]}"} 2>/dev/null) || answer=""
  ok=1
  printf '%s\n' "$answer" > "$here/results/$(date +%F)-$mode-$((total+1)).txt"
  printf '%s' "$answer" | grep -Eiq "$expect" || ok=0
  if [ -n "$forbid" ] && printf '%s' "$answer" | grep -Eiq "$forbid"; then ok=0; fi
  total=$((total+1)); [ $ok -eq 1 ] && pass=$((pass+1))
  printf '%s\t%s\t%s\n' "$skill" "$([ $ok -eq 1 ] && echo PASS || echo FAIL)" "$prompt" | tee -a "$out"
done < "$here/prompts.tsv"
echo "$mode: $pass/$total passed (results: $out)"
