#!/usr/bin/env bash
# check_ui_rules.sh: fail when lines ADDED since <base> break the lean UI rules.
# Existing code never blocks a PR; only new lines are checked.
#
# Usage:  scripts/check_ui_rules.sh [base-ref]      (default: origin/main)
# CI:     needs full history (actions/checkout with fetch-depth: 0)
#
# Exceptions:
#   .ui-rules-ignore   one git pathspec per line (# comments), for code that
#                      legitimately uses fixed pixels, e.g. share cards rendered
#                      to a fixed 1080x1920 canvas.
#   // ui-rules-ok: <reason>   on the line itself, for a single justified case
#                      (e.g. the Apple sign-in button must be black). The
#                      reason is required.
set -euo pipefail

base="${1:-origin/main}"
root="$(git rev-parse --show-toplevel)"

excludes=(
  ':(exclude)lib/common/theme/*'
  ':(exclude)lib/common/utils/responsive.dart'
  ':(exclude)*.g.dart'
  ':(exclude)*.freezed.dart'
)
if [ -f "$root/.ui-rules-ignore" ]; then
  while IFS= read -r spec || [ -n "$spec" ]; do
    spec="${spec%%#*}"; spec="$(echo "$spec" | xargs)"
    [ -n "$spec" ] && excludes+=(":(exclude)$spec")
  done < "$root/.ui-rules-ignore"
fi

# One alternative per rule (Perl regex: works with the macOS and Linux defaults).
# Matched against the added line's content only.
pattern='SizedBox\(\s*(height|width):\s*\d'                                   # fixed spacing
pattern+='|EdgeInsets\.(all|fromLTRB)\(\s*\d'                                # fixed padding
pattern+='|EdgeInsets\.(symmetric|only)\([^)\t]*\b(horizontal|vertical|left|right|top|bottom):\s*\d'
pattern+='|^\s*(horizontal|vertical):\s*\d'                                  # multi-line EdgeInsets.symmetric
pattern+='|fontSize:\s*\d'                                                   # fixed font size
pattern+='|\bColors\.(?!transparent\b)\w'                                    # raw colors
pattern+='|\bColor\(0x'
pattern+='|\b(Linear|Radial|Sweep)Gradient\('                                # AI slop
pattern+='|\bBackdropFilter\('
pattern+='|\bWidget\s+_build\w*\('                                           # extract a widget class
pattern+='|(?<![\w.])print\('                                                # use debugPrint / logger

violations=$(
  git -C "$root" diff --unified=0 --no-color "$base"...HEAD -- 'lib/*.dart' "${excludes[@]}" \
    | awk '
        /^\+\+\+ b\//      { file = substr($0, 7); next }
        /^\+\+\+ \/dev\/null/ { next }
        /^@@/              { split($3, r, ","); line = substr(r[1], 2) + 0; next }
        /^\+/              { printf "%s\t%s:%d\n", substr($0, 2), file, line; line++ }
      ' \
    | PATTERN="$pattern" perl -ne 'print if /^[^\t]*?(?:$ENV{PATTERN})/' \
    | perl -ne 'print unless /^[^\t]*ui-rules-ok:\s*\S/' \
    | awk -F'\t' '{ sub(/^[ \t]+/, "", $1); printf "  %s  %s\n", $2, $1 }' \
    || true
)

if [ -n "$violations" ]; then
  echo "UI rule violations in added lines (see the lean-flutter-ui skill):"
  echo "$violations"
  echo
  echo "Fix: spacing/fonts from responsive.dart tokens, colors from colorScheme,"
  echo "no gradients/blur, extract widget classes instead of _build methods."
  exit 1
fi
echo "UI rules: OK"
