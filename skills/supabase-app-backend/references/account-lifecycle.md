# Accounts: deletion, guests, auth settings, sessions, links

Read before building account deletion, guest mode, or changing auth settings.

## 1. Account deletion

Both stores require it in the app, Google Play also at a public web URL. Apple additionally
expects the Sign in with Apple token to be revoked (TN3194).

One edge function `delete-account` (JWT verified, the caller deletes **themselves**, the
user id comes from the JWT, never from the body). Order matters, each step idempotent so a
retry after a crash finishes the job:

1. Re-authenticate recently (the app asks for a fresh sign-in or a password) and require a typed confirmation.
2. Apple users: revoke the token (`POST https://appleid.apple.com/auth/revoke`, client secret
   JWT signed with the Sign in with Apple key). It needs the refresh token from the code
   exchange at login, so store it server-side at sign-in; without it revocation is impossible.
3. RevenueCat: the subscription is not cancelled by deleting the account. Tell the user in the
   confirmation sheet to cancel in the store, and delete the RevenueCat subscriber
   (`DELETE /v1/subscribers/{app_user_id}`) if the app is not allowed to keep purchase history.
4. PostHog: delete the person (`distinct_id` = user id) via the API or the app's retention rule.
5. Storage: remove `<uid>/` from every bucket.
6. Database rows: `on delete cascade` from `auth.users` covers owned rows; list the tables that
   must not cascade (shared content, reports) and decide anonymise vs delete for each.
7. `auth.admin.deleteUser(uid)` last.
8. App: wipe Drift (all tables), secure storage, pending outbox rows and caches, reset analytics
   (`reset()`), `logOut()` in RevenueCat, land on the signed-out start screen.

Test: a landing test that deletes the account and asserts the signed-out screen and an empty
local database; a function test that a second call after success returns 200 or 404, not 500.
Web page for Play: public URL that explains how to request deletion (and the in-app path).

## 2. Guests (anonymous sign-ins)

- Anonymous sign-ins are limited to 30 per hour per IP and are **never cleaned up
  automatically**. Every cold start that signs in a new guest creates a permanent `auth.users` row.
- Sign in a guest once and persist the session; never on every launch.
- Abuse control: turn on CAPTCHA (Cloudflare Turnstile) for anonymous sign-ins in the auth
  settings when the app has an open write path; otherwise rely on the rate limit plus quotas.
- Quotas in RLS/with-check or a trigger (rows per guest, bytes per guest) so a script cannot fill the database.
- Restrictive policy for what guests must not do: `((select auth.jwt() ->> 'is_anonymous')::boolean is not true)`.
- Cleanup job (pg_cron, weekly): delete anonymous users with no activity for 30 days that
  never linked an identity: `delete from auth.users where is_anonymous and last_sign_in_at < now() - interval '30 days'`.

## 3. Auth settings checklist

Put what `supabase/config.toml` can express in it (reviewed in PRs); the rest is a dashboard
checklist in the app's docs. Check each against the current docs when you set it up.

| Setting | Value |
|---|---|
| email OTP / link expiry | 1 hour or less |
| minimum password length and requirements | 8+ and letters + digits |
| leaked-password protection | on (dashboard, paid plan) |
| redirect URL allow-list | only the app's scheme and https host, no wildcards on foreign domains |
| rate limits (sign-in, OTP, anonymous) | defaults or stricter; never raised "to make a test pass" |
| anonymous sign-ins | on only if the app has guest mode |
| email confirmation | on |
| CAPTCHA | on if guests have write access |

## 4. Session storage on the device

The supabase_flutter default keeps the session in unencrypted shared preferences. Decide once:
store it through `flutter_secure_storage` (custom `LocalStorage` in `FlutterAuthClientOptions`)
**or** exclude the preferences file from Android backup (`android:fullBackupContent` /
`dataExtractionRules`) and iOS backup. Secure storage is the default choice; the exclusion is
the fallback for apps that cannot take the plugin. Either way, wipe on sign-out and account deletion.

## 5. Links and deep-link parameters

- A URL read from the database or an API is opened only when its scheme is `https` or `mailto`
  (`Uri.tryParse`, check `scheme`); anything else is dropped. `javascript:`, `file:` and custom
  schemes from data are never launched.
- A deep link parameter that names a record is accepted only if it parses as a UUID; otherwise
  land on the start screen. Never build SQL, paths or storage keys from a raw parameter.
- Test both with a fixture list of hostile values.
