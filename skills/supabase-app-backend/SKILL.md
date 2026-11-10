---
name: supabase-app-backend
description: Backend conventions for mobile apps on Supabase - migrations, RLS, grants, storage, edge functions, backward-compatible deploys, native Apple/Google login and guest conversion, Resend mail, Namecheap DNS, Firebase push, secrets. Use for supabase/ work, auth flows, email, domains or env keys.
---

# App backend stack

| Concern | Service |
|---|---|
| DB, auth, storage, edge functions | Supabase |
| Login | Native Apple + Google → `supabase.auth.signInWithIdToken`, email/password, anonymous guest sessions |
| Push | Firebase Cloud Messaging (Firebase is used **only** for push) |
| Mail | Resend, server-side only |
| Domain + DNS | Namecheap |
| Analytics / paywall | PostHog / RevenueCat (skills `posthog-analytics`, `revenuecat-purchases`) |

Each app has its own repo (Flutter app + its Supabase project); newsletter and outreach code
lives in a separate marketing repo. App-specific function and table names are in the repo's
CLAUDE.md.

## Secrets: two files, the split matters

- `.env` is bundled as an asset, so **anyone can read it**. Only publishable keys:
  `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `POSTHOG_*`, RevenueCat public keys.
- `.env.tools` is never bundled; only `tool/` or `scripts/` read it. It holds
  `SUPABASE_SECRET_KEY` and `SUPABASE_DB_PASSWORD`.
- **Key names:** the publishable key (`sb_publishable_...`) replaces the legacy `anon` JWT, the
  secret key (`sb_secret_...`) replaces `service_role`. Supabase deprecates the legacy keys
  (end of 2026) and they cannot be rotated independently of the JWT secret. Move a project
  over in the dashboard, switch the env names, then disable the legacy keys. The roles keep
  their names in SQL (`anon`, `authenticated`, `service_role`).
- Edge function secrets (`RESEND_API_KEY`, the secret key) live only in
  `supabase secrets set`.
- Each env file ships an `.example` with empty values. `Env.load()` throws if a tools key
  turns up in `.env`.
- **Both files are git-ignored**, bundled or not; only the `.example` files are tracked.
  gitleaks (hook + CI) and `scripts/check_secrets.sh` guard this: see the app-release skill,
  *Secrets never reach git*. A leaked secret (service role) key bypasses all RLS: rotate it at once.

## Database changes

**Read [references/migrations-and-deploys.md](references/migrations-and-deploys.md) before
writing a migration.** The short version:

1. A new timestamped file in `supabase/migrations/`. Never edit, squash or re-baseline a
   migration that ran on prod: a squash once silently removed grants, storage policies and
   push triggers in production.
2. **Never rely on default privileges.** Supabase stops exposing new tables to the Data API
   automatically (new projects since 2026-05-30; existing projects were announced for
   2026-10-30, check yours). Every new table gets, in the same migration: `create table`,
   `grant` per role with least privilege (sequences too), `enable row level security`, and
   explicit policies. Start from [references/migration-template.sql](references/migration-template.sql).
   Server-only tables: RLS on, no client policies, grant to `service_role` only.
3. Policies use `(select auth.uid())`, not a bare `auth.uid()`, and every column a policy
   filters on has an index. Guests are `authenticated` too (anonymous sessions).
4. `security definer` functions: `set search_path = ''` and schema-qualified names.
5. User-writable text columns get length and format checks; buckets get a size limit and a
   MIME allowlist.
6. RLS tests in `supabase/tests/`: anon, owner, another user, guest.
7. Run the Supabase advisors (security + performance) after applying; fix what they report.
8. **Backward compatible with every app version still in the stores.** Additive changes ship
   any time; destructive ones go expand → migrate → contract behind a minimum-version gate.
9. If the app mirrors the table in Drift: Drift table, `schemaVersion`, mapper and a migration
   test in the same PR.

## Storage

- Private buckets; clients get signed URLs from a signing edge function.
- Object paths start with the owner id (`<uid>/...`); policies match
  `(storage.foldername(name))[1] = (select auth.uid())::text`.
- **Uploads need a SELECT policy.** The storage server's multipart path does a pre-flight
  SELECT, so without one every upload fails with a misleading "violates row-level security"
  403. Scope it to the owner's folder; a bucket-wide SELECT lets any user list every user's
  files.
- Tables store object **paths**, never public URLs, signed URLs or device paths.

## Edge functions (Deno)

- One function per job in `supabase/functions/<name>/`; shared code in `_shared/`.
- Verify the JWT unless it is a webhook: leave `verify_jwt` on (the default) for client calls,
  turn it off only for webhooks and check their shared secret in code. Current Supabase docs
  wrap handlers with `withSupabase` and read keys from `SUPABASE_SECRET_KEYS`; if the project
  already uses that wrapper, follow it, otherwise keep the plain `Deno.serve` handler and read
  the secret key from the function's env. Webhooks (RevenueCat, Postgres triggers via
  `pg_net`) check their shared secret first. The RevenueCat webhook and the `is_pro`
  grant: revenuecat-purchases, server entitlement.
- Service role only inside the function; re-check ownership in code.
- JSON errors with a status code. Logs without personal data.
- Never hardcode a project URL in SQL or code that runs in several environments.

## Native login

- **Apple:** raw nonce → send `sha256(raw)` to Apple → pass the raw nonce to
  `signInWithIdToken`. iOS uses the official `SignInWithAppleButton`.
- **Google (google_sign_in 7):** `GoogleSignIn.instance.initialize(...)` on every attempt with
  `serverClientId: <web client>` (the audience Supabase validates) and `nonce: sha256(raw)`;
  pass the raw nonce to Supabase. Without a nonce GoTrue rejects the token ("nonce ... should
  either both exist or not").
- `clientId` (the iOS client) on iOS only. Android resolves the client from package name +
  SHA-1. **Every signing key (debug, upload, Play App Signing) needs its SHA-1 in Google
  Cloud**, or release builds fail while debug works.
- Fall back from the native flow to web OAuth only when native is unavailable, never on a
  real error: the fallback turns an error such as an identity collision into a silent
  "still not signed in".
- Track `login_started`, `login_completed`, `login_failed` (event names: posthog-analytics) with method and error code.

## Accounts, guests, push

- **Account deletion, guest abuse and cleanup, auth settings, session storage, link and
  deep-link validation:** read [references/account-lifecycle.md](references/account-lifecycle.md).
- **Push (tokens, permission, sending, setup):** read [references/push.md](references/push.md).

## Guest → account conversion

Guests are anonymous Supabase sessions converted with `linkIdentityWithIdToken`.
- The `is_anonymous` claim stays `true` until the next token refresh. Derive "is guest" from
  the user's identities, not from the claim alone, or the router keeps the converted user in
  guest mode.
- `identity_already_exists` means the Google/Apple identity already has an account: offer
  "sign in to that account instead" explicitly, and say what happens to the guest's data.
- After the user id changes, everything user-scoped must rebuild: providers watch the id,
  Drift reads filter by it (see the flutter-feature-stack skill).

## Resend

- Send from a subdomain only: `news@mail.<domain>` (newsletter), `hello@mail.<domain>`
  (transactional). The root domain never sends, so complaints cannot hurt the website domain.
- The sender address lives in one shared constant, never inline per function.
- Add the subdomain in Resend as its own domain and copy exactly the records Resend shows
  into Namecheap (SPF TXT and bounce MX on `send.mail`, DKIM TXT on `resend._domainkey.mail`),
  plus DMARC on `_dmarc.mail` (start `p=none; rua=mailto:<you>`, move to `quarantine` after 2–4
  clean weeks).
- Warm up a new sending domain: confirmations first, then small batches.
- Bulk mail: `List-Unsubscribe` + `List-Unsubscribe-Post: List-Unsubscribe=One-Click`, double
  opt-in, unsubscribes honoured immediately.
- Supabase Auth mails go through Resend SMTP (`smtp.resend.com`, port 465, user `resend`, the
  API key as password), sender on the same subdomain.

## Namecheap

- Namecheap stays the nameserver unless a host needs otherwise. Every record is documented in
  the repo (`docs/INTERFACE.md` or `docs/dns.md`).
- Universal / app links: `/.well-known/apple-app-site-association` and
  `/.well-known/assetlinks.json` served from the website over HTTPS without a redirect.
- Verify DNS changes with `dig TXT <host>` before moving on.

## Done means

Migration applied locally, RLS tests green, advisors clean, compatible with the oldest app
version in the stores, types and mappers updated, secrets in the right file, docs updated if
a record or key changed.
