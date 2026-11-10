#!/usr/bin/env bash
# check_layers.sh: fail when IMPORT lines added since <base> break the layer table.
# Existing code never blocks a PR; only new imports are checked.
#
# Usage:  scripts/check_layers.sh [base-ref]      (default: origin/main)
#         scripts/check_layers.sh --file <path>   every import of one file (for hooks)
# Exit:   0 clean, 1 violations, 2 the base ref does not exist
# Escape: `// layers-ok: <reason>` on the import line (reason required).
#
# Table (lib/features/<f>/<layer>/ and lib/common/):
#   domain        no flutter, riverpod, supabase, drift; no data/controller/presentation
#   data          no controller, presentation
#   application   no presentation
#   controller    no widgets (flutter/material|widgets|cupertino), no presentation
#   presentation  no supabase, drift, data/, DAOs, repository impls, common/database
set -euo pipefail

file_mode=""
if [ "${1:-}" = "--file" ]; then file_mode="${2:?--file needs a path}"; base=""; else base="${1:-origin/main}"; fi
root="$(git rev-parse --show-toplevel)"
if [ -n "$base" ] && ! git -C "$root" rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "check_layers: base ref '$base' not found (CI needs fetch-depth: 0)" >&2; exit 2
fi

layer_of() { # path -> domain|data|application|controller|presentation|""
  case "$1" in
    */domain/*) echo domain ;; */data/*) echo data ;; */application/*) echo application ;;
    */controller/*) echo controller ;; */presentation/*) echo presentation ;; *) echo "" ;;
  esac
}
forbidden() { # layer -> perl regex on the import line
  case "$1" in
    domain)       echo "package:(flutter|flutter_riverpod|riverpod|riverpod_annotation|supabase|supabase_flutter|drift)/|/(data|controller|presentation|application)/" ;;
    data)         echo "/(controller|presentation)/" ;;
    application)  echo "/presentation/" ;;
    controller)   echo "package:flutter/(material|widgets|cupertino)\.dart|/presentation/" ;;
    presentation) echo "package:(supabase|supabase_flutter|drift)/|/data/|\.dao\.dart|\.repository\.impl\.dart|common/database/" ;;
  esac
}

# "path<TAB>line<TAB>content" for each import line to check
imports() {
  if [ -n "$file_mode" ]; then
    awk -v f="$file_mode" '/^[[:space:]]*(import|export)[[:space:]]/ { printf "%s\t%d\t%s\n", f, NR, $0 }' "$file_mode"
  else
    git -C "$root" diff --unified=0 --no-color "$base"...HEAD -- 'lib/*.dart' ':(exclude)*.g.dart' ':(exclude)*.freezed.dart' \
      | awk '/^\+\+\+ b\//{f=substr($0,7);next} /^@@/{match($0,/\+[0-9]+/);n=substr($0,RSTART+1,RLENGTH-1)-1;next}
             /^\+/{n++; s=substr($0,2); if (s ~ /^[ \t]*(import|export)[ \t]/) printf "%s\t%d\t%s\n", f, n, s}'
  fi
}

bad=0
while IFS=$'\t' read -r f n content; do
  [ -n "$f" ] || continue
  layer=$(layer_of "$f"); [ -n "$layer" ] || continue
  case "$content" in *"// layers-ok:"*[![:space:]]*) continue ;; esac
  re=$(forbidden "$layer")
  if printf '%s\n' "$content" | RE="$re" perl -ne 'exit(/$ENV{RE}/ ? 0 : 1)'; then
    echo "$f:$n: $layer must not import this: $(echo "$content" | xargs)"; bad=1
  fi
done < <(imports)

if [ $bad -eq 1 ]; then
  echo "check_layers: see the layer table in skills/flutter-feature-stack (add '// layers-ok: <reason>' only for a justified case)" >&2
  exit 1
fi
echo "check_layers: ok"
