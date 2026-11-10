#!/usr/bin/env bash
# check_file_sizes.sh: size limits as a ratchet. A file over its limit may not grow.
#
# Limits: *.provider.dart 400, every other Dart file under lib/ 300 lines.
# Baseline: .file-size-baseline (committed), lines "<lines> <path>" for files already over.
#
# Usage:  scripts/check_file_sizes.sh                check the tree against the baseline
#         scripts/check_file_sizes.sh --update       rewrite the baseline (only shrinks are expected)
#         scripts/check_file_sizes.sh --file <path>  one file (for hooks)
# Exit:   0 ok, 1 a file is new over the limit or grew
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
baseline="$root/.file-size-baseline"

limit_of() { case "$1" in *.provider.dart) echo 400 ;; *) echo 300 ;; esac; }
skip() { case "$1" in *.g.dart|*.freezed.dart|*.gr.dart|*/generated/*|*/l10n/*) return 0 ;; esac; return 1; }
over() { # prints "<lines> <path>" for every file over its limit
  git -C "$root" ls-files 'lib/*.dart' | while read -r f; do
    skip "$f" && continue
    [ -f "$root/$f" ] || continue
    n=$(wc -l < "$root/$f" | tr -d ' ')
    [ "$n" -gt "$(limit_of "$f")" ] && echo "$n $f"
  done
  return 0
}

case "${1:-}" in
  --update) over | sort -k2 > "$baseline"; echo "wrote $(wc -l < "$baseline" | tr -d ' ') entries to .file-size-baseline"; exit 0 ;;
  --file)
    f="${2:?--file needs a path}"; rel="${f#"$root"/}"; skip "$rel" && exit 0
    n=$(wc -l < "$f" | tr -d ' '); lim=$(limit_of "$rel")
    [ "$n" -le "$lim" ] && exit 0
    old=$(awk -v p="$rel" '$2==p{print $1}' "$baseline" 2>/dev/null || true)
    if [ -z "$old" ] || [ "$n" -gt "$old" ]; then echo "$rel: $n lines, limit $lim${old:+, was $old}; split it by sub-feature"; exit 1; fi
    exit 0 ;;
esac

bad=0
while read -r n f; do
  [ -n "$f" ] || continue
  old=$(awk -v p="$f" '$2==p{print $1}' "$baseline" 2>/dev/null || true)
  if [ -z "$old" ]; then echo "$f: $n lines, limit $(limit_of "$f") (new over the limit)"; bad=1
  elif [ "$n" -gt "$old" ]; then echo "$f: grew from $old to $n lines"; bad=1; fi
done < <(over)
[ $bad -eq 1 ] && { echo "check_file_sizes: split the file by sub-feature, or run --update only if it shrank" >&2; exit 1; }
echo "check_file_sizes: ok"
