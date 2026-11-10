#!/usr/bin/env bash
# check_ui_rules.sh: fail when lines ADDED since <base> break the lean UI rules.
# Existing code never blocks a PR; only new lines are checked.
#
# Usage:  scripts/check_ui_rules.sh [base-ref]      (default: origin/main)
#         scripts/check_ui_rules.sh --file <path>   every line of one file (for hooks)
# Exit:   0 clean, 1 violations, 2 the base ref does not exist
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

file_mode=""
if [ "${1:-}" = "--file" ]; then
  file_mode="${2:?--file needs a path}"
  base=""
else
  base="${1:-origin/main}"
fi
root="$(git rev-parse --show-toplevel)"

# A missing base (shallow checkout, typo) must never read as "no violations".
if [ -n "$base" ] && ! git -C "$root" rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "check_ui_rules: base ref '$base' not found (CI needs fetch-depth: 0)" >&2
  exit 2
fi

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
pattern+='|\bColor\.from(ARGB|RGBO)\('
pattern+='|\b(Linear|Radial|Sweep)Gradient\('                                # AI slop
pattern+='|\bBackdropFilter\('
pattern+='|\bImageFilter\.blur\('
pattern+='|\bblurRadius:\s*(1[1-9]|[2-9]\d|\d{3,})'                          # blur > 10
pattern+='|\b(sigmaX|sigmaY):\s*(1[1-9]|[2-9]\d|\d{3,})'
pattern+='|\belevation:\s*([2-9]|\d{2,})'                                    # elevation > 1
pattern+='|\b(BorderRadius|Radius)\.circular\(\s*\d'                         # radius from a token
pattern+='|\bGap\(\s*\d'
pattern+='|MediaQuery\.of\(\s*context\s*\)\.size\b'                          # use MediaQuery.sizeOf
pattern+='|[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]'                           # emoji as icon or copy
pattern+='|\bWidget\s+_build\w*\('                                           # extract a widget class
pattern+='|(?<![\w.])print\('                                                # use debugPrint / logger

# Lines as "content<TAB>file:line": added lines of the diff, or a whole file.
lines() {
  if [ -n "$file_mode" ]; then
    case "$file_mode" in
      *.g.dart|*.freezed.dart|*lib/common/theme/*|*lib/common/utils/responsive.dart) return ;;
    esac
    awk -v f="$file_mode" '{ printf "%s\t%s:%d\n", $0, f, NR }' "$file_mode"
  else
    git -C "$root" diff --unified=0 --no-color "$base"...HEAD -- 'lib/*.dart' "${excludes[@]}" \
      | awk '
          /^\+\+\+ b\//      { file = substr($0, 7); next }
          /^\+\+\+ \/dev\/null/ { next }
          /^@@/              { split($3, r, ","); line = substr(r[1], 2) + 0; next }
          /^\+/              { printf "%s\t%s:%d\n", substr($0, 2), file, line; line++ }
        '
  fi
}

# Comment lines are skipped; a trailing comment is cut before matching, except
# the ui-rules-ok marker, which is checked on the full line.
violations=$(
  lines \
    | perl -CSD -ne 'print unless /^\s*(\/\/|\*|\/\*)/' \
    | perl -CSD -ne 'print unless /^[^\t]*ui-rules-ok:\s*\S/' \
    | PATTERN="$pattern" perl -CSD -ne '
        my ($code) = /^([^\t]*)/; $code =~ s/\s\/\/.*$//;
        print if $code =~ /(?:$ENV{PATTERN})/' \
    | awk -F'\t' '{ sub(/^[ \t]+/, "", $1); printf "  %s  %s\n", $2, $1 }'
)

if [ -n "$violations" ]; then
  echo "UI rule violations in added lines (see the lean-flutter-ui skill):"
  echo "$violations"
  echo
  echo "Fix: spacing/fonts from responsive.dart tokens, colors from colorScheme,"
  echo "radius from a token, no gradients/blur/emoji, MediaQuery.sizeOf, widget classes"
  echo "instead of _build methods."
  exit 1
fi
echo "UI rules: OK"
