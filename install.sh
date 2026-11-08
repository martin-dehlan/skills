#!/usr/bin/env bash
# Makes this repo's skills and agents available in every Claude Code session.
#
#   skills  → one symlink per skill in ~/.claude/skills/ (git pull updates them in place)
#   agents  → copied into ~/.claude/agents/ (re-run this script after pulling agent changes)
#
# Safe to re-run. Never overwrites a real file or directory that is not ours.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$claude_dir/skills" "$claude_dir/agents"

for dir in "$repo"/skills/*/; do
  name="$(basename "$dir")"
  target="$claude_dir/skills/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "skip   skill $name: $target exists and is not a symlink"
    continue
  fi
  ln -sfn "$repo/skills/$name" "$target"
  echo "linked skill $name"
done

for file in "$repo"/agents/*.md; do
  name="$(basename "$file")"
  target="$claude_dir/agents/$name"
  if [ -L "$target" ]; then rm "$target"; fi
  if [ -e "$target" ] && ! grep -q "^name: ${name%.md}$" "$target"; then
    echo "skip   agent ${name%.md}: $target exists and is not ours"
    continue
  fi
  cp "$file" "$target"
  echo "copied agent ${name%.md}"
done

echo
echo "Done. Restart Claude Code, then check with /skills and /agents."
