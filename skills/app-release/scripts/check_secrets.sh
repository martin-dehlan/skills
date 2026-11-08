#!/usr/bin/env bash
# Checks that secrets cannot reach git: scanner installed and wired up,
# .gitignore covers the usual secret files, nothing sensitive is tracked,
# and the history (or the branch) scans clean.
#
#   bash scripts/check_secrets.sh              # full history
#   bash scripts/check_secrets.sh origin/main  # only commits since that ref (CI on PRs)
#
# Exit 1 on any "fail". "warn" lines do not fail the run.
set -uo pipefail

base="${1:-}"
root="$(git rev-parse --show-toplevel)" || exit 1
cd "$root"

fails=0
warns=0
ok()   { echo "  ok    $1"; }
warn() { echo "  warn  $1"; warns=$((warns + 1)); }
fail() { echo "  FAIL  $1"; fails=$((fails + 1)); }

echo "Secret hygiene"

# 1. Scanner
if command -v gitleaks >/dev/null 2>&1; then
  ok "gitleaks installed ($(gitleaks version 2>/dev/null))"
else
  fail "gitleaks not installed: brew install gitleaks"
fi

if [ -f .gitleaks.toml ]; then
  ok ".gitleaks.toml present"
else
  fail ".gitleaks.toml missing (copy the template from the skills repo)"
fi

# 2. Local hook (skipped in CI, where hooks never run)
if [ -z "${CI:-}" ]; then
  hook=".git/hooks/pre-commit"
  if [ -e "$hook" ] && grep -q gitleaks "$hook" 2>/dev/null; then
    ok "pre-commit hook runs gitleaks"
  else
    fail "pre-commit hook missing or not running gitleaks: bash scripts/install-git-hooks.sh"
  fi
fi

# 3. CI backstop
if grep -lqs gitleaks .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null; then
  ok "a CI workflow runs gitleaks"
else
  fail "no CI workflow runs gitleaks (copy secret-scan.yml from the skills repo)"
fi

# 4. .gitignore covers secret files (pattern check, works whether or not the file exists)
must_ignore=".env .env.local .env.tools .env.dev android/key.properties android/app/upload.jks
release.keystore AuthKey_ABC123.p8 cert.p12 private.pem private.key service-account.json
supabase/.temp/x"
missing=""
for p in $must_ignore; do
  git check-ignore -q --no-index "$p" || missing="$missing $p"
done
if [ -z "$missing" ]; then
  ok ".gitignore covers env files, keystores, signing keys, service accounts"
else
  fail ".gitignore does not cover:$missing"
fi

# Firebase client configs: not secret on their own, but they carry API keys that get abused
# when unrestricted. Ignore them and ship a template, or restrict the keys.
fb_missing=""
for p in android/app/google-services.json ios/Runner/GoogleService-Info.plist lib/firebase_options.dart; do
  git check-ignore -q --no-index "$p" || fb_missing="$fb_missing $p"
done
if [ -z "$fb_missing" ]; then
  ok ".gitignore covers Firebase client configs"
else
  warn "Firebase configs not ignored:$fb_missing (fine only if their API keys are restricted)"
fi

for p in .env.example; do
  if git check-ignore -q --no-index "$p"; then
    warn "$p is ignored: add '!.env.example' so the template stays in git"
  fi
done

# 5. Nothing sensitive is tracked right now
tracked="$(git ls-files | grep -i -E \
  '(^|/)\.env($|\.)|\.jks$|\.keystore$|\.p8$|\.p12$|\.pem$|\.key$|(^|/)key\.properties$|google-services\.json$|GoogleService-Info\.plist$|service.?account[^/]*\.json$|(^|/)firebase_options\.dart$|\.mobileprovision$' \
  | grep -v -E '\.(example|template|sample)$|\.template\.dart$|\.example\.' || true)"
if [ -z "$tracked" ]; then
  ok "no secret-shaped files tracked"
else
  fail "secret-shaped files are tracked (git rm --cached, then rotate the secret):"
  echo "$tracked" | sed 's/^/          /'
fi

# 6. Content scan
if command -v gitleaks >/dev/null 2>&1; then
  args=(git --redact --no-banner --log-level error)
  [ -f .gitleaks.toml ] && args+=(--config .gitleaks.toml)
  if [ -n "$base" ]; then
    args+=(--log-opts "$base..HEAD")
    scope="commits since $base"
  else
    scope="full history"
  fi
  if gitleaks "${args[@]}" . >/dev/null 2>&1; then
    ok "gitleaks: no leaks in $scope"
  else
    fail "gitleaks found leaks in $scope: run 'gitleaks ${args[*]} .' to see them"
  fi
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "Secret hygiene: $fails failed, $warns warnings"
  exit 1
fi
[ "$warns" -gt 0 ] && echo "Secret hygiene: OK with warnings" || echo "Secret hygiene: OK"
