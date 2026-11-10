#!/usr/bin/env bash
# Roll the check scripts and templates listed in sync.manifest into an app, or report drift.
#   sync.sh <app-dir>           copy managed files (stamped), copy seed files only if missing
#   sync.sh --check <app-dir>   change nothing; exit 1 if a managed copy differs or is missing
# Needs bash 3.2+, git, cmp.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
MANIFEST="$ROOT/sync.manifest"
check=0
if [ "${1:-}" = "--check" ]; then check=1; shift; fi
app=${1:-}
[ -n "$app" ] && [ -d "$app" ] || { echo "usage: sync.sh [--check] <app-dir>" >&2; exit 2; }
app=$(cd "$app" && pwd)

sha=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ $check -eq 0 ] && [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
  echo "warning: $ROOT has uncommitted changes; the stamp skills@$sha will not match the content" >&2
fi

# the stamp line is not part of the content that is compared
strip() { grep -v '^# skills@' "$1" || true; }

stamp() { # src dest
  local src=$1 dest=$2 line="# skills@$sha (managed by skills/sync.sh, edit it there)"
  mkdir -p "$(dirname "$dest")"
  if head -n1 "$src" | grep -q '^#!'; then
    { head -n1 "$src"; echo "$line"; tail -n +2 "$src"; } > "$dest"
  else
    { echo "$line"; cat "$src"; } > "$dest"
  fi
  chmod --reference="$src" "$dest" 2>/dev/null || chmod "$(stat -f '%Lp' "$src")" "$dest"
}

drift=0
while IFS=$'\t' read -r mode src dest; do
  case "$mode" in ''|\#*) continue ;; esac
  [ -f "$ROOT/$src" ] || { echo "manifest error: $src does not exist" >&2; exit 2; }
  target="$app/$dest"
  case "$mode" in
    managed)
      if [ ! -f "$target" ]; then
        if [ $check -eq 1 ]; then echo "MISSING  $dest"; drift=1
        else stamp "$ROOT/$src" "$target"; echo "added    $dest"; fi
      elif [ "$(strip "$target")" != "$(strip "$ROOT/$src")" ]; then
        if [ $check -eq 1 ]; then echo "DRIFT    $dest"; drift=1
        else stamp "$ROOT/$src" "$target"; echo "updated  $dest"; fi
      else
        [ $check -eq 1 ] || echo "current  $dest"
      fi ;;
    seed)
      if [ -f "$target" ]; then
        [ $check -eq 1 ] || echo "kept     $dest (app-owned)"
      elif [ $check -eq 1 ]; then echo "absent   $dest (seed, not a failure)"
      else mkdir -p "$(dirname "$target")"; cp -p "$ROOT/$src" "$target"; echo "seeded   $dest"; fi ;;
    *) echo "manifest error: unknown mode '$mode'" >&2; exit 2 ;;
  esac
done < "$MANIFEST"

if [ $check -eq 1 ]; then
  [ $drift -eq 0 ] && echo "in sync with skills@$sha" || echo "run: $ROOT/sync.sh $app" >&2
  exit $drift
fi
