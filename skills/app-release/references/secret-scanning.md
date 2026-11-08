# Secret scanning

Three layers, because each one alone has a gap:

| Layer | Catches | Misses |
|---|---|---|
| `.gitignore` | whole files (`.env`, keystores, `.p8`, service accounts) before `git add` | a key pasted into a tracked file; `git add -f` |
| gitleaks pre-commit hook | key-shaped strings in staged changes | a fresh clone that never ran the installer; `--no-verify` |
| gitleaks in CI | everything on the PR, whoever pushed it | nothing new, but it only fires after the push |

A fourth check, `scripts/check_secrets.sh`, verifies that the three layers exist and that no
secret-shaped file is tracked. gitleaks reads content, so a binary keystore or a `.p8` that
was committed by name is found only by the tracked-file check.

## Setup in a new app (copy from `templates/secrets/` in the skills repo)

1. `brew install gitleaks`
2. Append `gitignore-secrets.txt` to `.gitignore`. Keep `!.env.example` so the template stays
   in git.
3. Copy `gitleaks.toml` → `.gitleaks.toml`. Add app-specific placeholder paths to its
   allowlist only (templates, `*.example`, lockfiles with checksums).
4. Copy `pre-commit` → `scripts/git-hooks/pre-commit` and `install-git-hooks.sh` →
   `scripts/install-git-hooks.sh`. Run `bash scripts/install-git-hooks.sh` once per clone and
   list that command in the app's CLAUDE.md under Commands.
5. Copy `secret-scan.yml` → `.github/workflows/secret-scan.yml`. It needs `fetch-depth: 0`
   and `pull-requests: read`; without the latter the action 403s and looks like a leak.
6. Copy `scripts/check_secrets.sh` from the app-release skill and run it.

## When the hook blocks a commit

- **Real secret:** unstage it, move the value into the right env file (see the
  supabase-app-backend skill for which keys go where), commit again.
- **False positive:** narrow allowlist entry in `.gitleaks.toml` (a path or an exact regex) in
  the same commit, with a comment saying why. Never `--no-verify`, never a broad regex.
- `.gitleaksignore` is only for findings in history that were already rotated. It is never
  the answer to a new finding.

## When a secret was pushed

Pushed means leaked, even on a private repo: forks, CI logs, clones and caches keep it.

1. **Rotate first.** Revoke the key at the provider (Supabase, Google Cloud, Resend,
   RevenueCat, Apple) and deploy the new one to every place that uses it.
2. Remove the value in a normal follow-up commit.
3. Add the old finding to `.gitleaksignore` (`<commit>:<file>:<rule>:<line>`) with a comment
   saying it was rotated.
4. Rewriting history is optional cleanup, never the fix: the key is already out.

## Publishable vs secret

Some keys are meant to ship in the app binary: the Supabase anon/publishable key, PostHog
project key, RevenueCat public SDK keys, Firebase client API keys. They are fine in a bundled
`.env`, but that `.env` is still git-ignored (environments differ, and it is the first place a
real secret gets pasted by mistake). Firebase / Google API keys must be restricted to the app's
bundle id, package + SHA-1 and the APIs it uses, or anyone can bill against them.

Never in the app or in git: Supabase service role key, database password, any `sk_` / secret
API key, Apple `.p8` keys, Play service-account JSON, upload keystore and its passwords.
