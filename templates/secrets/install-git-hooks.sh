#!/usr/bin/env bash
# Once per clone: link the versioned hooks in scripts/git-hooks into .git/hooks.
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
mkdir -p "$root/.git/hooks"
for hook in "$root"/scripts/git-hooks/*; do
  name="$(basename "$hook")"
  chmod +x "$hook"
  ln -sf "../../scripts/git-hooks/$name" "$root/.git/hooks/$name"
  echo "linked $name"
done
