#!/usr/bin/env bash
# Run the eval prompts through Claude Code and score the answers against evals/prompts.tsv.
#   evals/run.sh [--skill <name>] [--off]     (--off uses an empty config dir: the baseline without skills)
# Needs: `claude` on PATH, logged in. Costs tokens: 30 prompts per pass. Output: one line per
# prompt (PASS/FAIL/ERROR) and a total, plus results in <results>/<date>-<on|off>.tsv and every
# answer in <results>/<date>-<on|off>/<n>.txt (n = line in prompts.tsv), so a FAIL can be read.
# Env: EVAL_OFF_CONFIG_DIR (default: a temp dir) for --off; EVAL_MODEL (default: the CLI default);
#      EVAL_RESULTS_DIR (default: evals/results).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
only=""; mode=on
while [ $# -gt 0 ]; do case "$1" in --skill) only="$2"; shift 2 ;; --off) mode=off; shift ;; *) echo "unknown arg $1" >&2; exit 2 ;; esac; done
command -v claude >/dev/null || { echo "claude not found" >&2; exit 2; }
res="${EVAL_RESULTS_DIR:-$here/results}"; out="$res/$(date +%F)-$mode.tsv"; ans="${out%.tsv}"
mkdir -p "$ans"; : > "$out"
if [ "$mode" = off ]; then export CLAUDE_CONFIG_DIR="${EVAL_OFF_CONFIG_DIR:-$(mktemp -d)}"; fi
model=(); [ -n "${EVAL_MODEL:-}" ] && model=(--model "$EVAL_MODEL")
pass=0; total=0; n=0
# A pattern grep cannot compile (exit 2) is an ERROR, never a silent match or miss.
match() { printf '%s' "$1" | grep -Eiq -- "$2"; }
while IFS=$'\t' read -r skill prompt expect forbid; do
  n=$((n+1))
  case "$skill" in ''|\#*) continue ;; esac
  [ -n "$only" ] && [ "$skill" != "$only" ] && continue
  # </dev/null: otherwise claude reads the rest of prompts.tsv from stdin as part of the prompt
  answer=$(cd "$(mktemp -d)" && claude -p "$prompt" ${model[@]+"${model[@]}"} </dev/null 2>/dev/null) || answer=""
  printf '%s\n' "$answer" > "$ans/$n.txt"
  verdict=PASS
  match "$answer" "$expect"; rc=$?
  [ $rc -eq 1 ] && verdict=FAIL; [ $rc -gt 1 ] && verdict=ERROR
  if [ -n "$forbid" ] && [ $verdict = PASS ]; then
    match "$answer" "$forbid"; rc=$?
    [ $rc -eq 0 ] && verdict=FAIL; [ $rc -gt 1 ] && verdict=ERROR
  fi
  total=$((total+1)); [ $verdict = PASS ] && pass=$((pass+1))
  printf '%s\t%s\t%s\t%s\n' "$skill" "$verdict" "$prompt" "$ans/$n.txt" | tee -a "$out"
done < "$here/prompts.tsv"
echo "$mode: $pass/$total passed (results: $out)"
