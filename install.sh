#!/usr/bin/env bash
# Makes this repo's skills and agents available in every Claude Code session.
#
#   ./install.sh          install or update: the live copy follows origin/main
#   ./install.sh --dev    link this working tree instead (to try a branch; undo
#                         with a plain ./install.sh)
#
# The skills are served from a separate worktree ("live", default
# ../skills-live, detached at origin/main), not from this clone. Otherwise every
# session would run whatever branch happens to be checked out here, reviewed or
# not. Develop here or in other worktrees; never edit the live one.
#
#   skills  → one symlink per skill in ~/.claude/skills/
#   agents  → copied into ~/.claude/agents/
#
# Safe to re-run. Never overwrites a real file or directory that is not ours.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
live="${SKILLS_LIVE_DIR:-$(dirname "$repo")/skills-live}"
mode="${1:-}"

case "$mode" in
  --dev) source_dir="$repo"; echo "dev mode: serving the working tree at $repo ($(git -C "$repo" branch --show-current))" ;;
  "")
    git -C "$repo" fetch -q origin main
    if [ ! -e "$live/.git" ]; then
      git -C "$repo" worktree add -q --detach "$live" origin/main
    else
      if [ -n "$(git -C "$live" status --porcelain)" ]; then
        echo "the live copy at $live has local changes; move them to a branch in $repo first" >&2
        exit 1
      fi
      git -C "$live" checkout -q --detach origin/main
    fi
    source_dir="$live"
    echo "live: $live at $(git -C "$live" log -1 --format='%h %s')"
    ;;
  *) echo "usage: $0 [--dev]" >&2; exit 2 ;;
esac

mkdir -p "$claude_dir/skills" "$claude_dir/agents"

# Drop links to skills of ours that no longer exist (renamed or removed).
for link in "$claude_dir"/skills/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    "$repo"/skills/*|"$live"/skills/*) [ -e "$link" ] || { rm "$link"; echo "removed stale link $(basename "$link")"; } ;;
  esac
done

for dir in "$source_dir"/skills/*/; do
  name="$(basename "$dir")"
  target="$claude_dir/skills/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "skip   skill $name: $target exists and is not a symlink"
    continue
  fi
  ln -sfn "$source_dir/skills/$name" "$target"
  echo "linked skill $name"
done

for file in "$source_dir"/agents/*.md; do
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
