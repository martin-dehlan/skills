# Server-verified Pro

The app's `isPro` is a UI hint. The database decides what a user may do.

## The column

- `profiles.is_pro boolean not null default false`, plus `pro_expires_at timestamptz` and
  `pro_updated_at timestamptz` so stale and manual rows are visible.
- **Only the service role writes it.** A per-row "update own profile" policy plus a table-wide
  `UPDATE` grant let any signed-in user `PATCH {"is_pro": true}` through PostgREST. That was
  a critical audit finding. Revoke the table grant and re-grant column by column:

```sql
revoke update on public.profiles from authenticated, anon;
grant update (username, display_name, avatar_url /*, every other user column */)
  on public.profiles to authenticated;
```

- Every new profile column must be added to that grant, or the app loses write access to it.
  Note it next to the grant.
- Server logic reads it in `security definer` functions (`check_and_consume_<thing>()`),
  never a flag the client sends. Cap Pro limits instead of making them unlimited: a
  compromised Pro account then costs a bounded amount.
- Gated content (Pro media) in a private bucket served through signed URLs from a function
  that checks `is_pro`, or rows behind an RLS policy that reads it.

## The webhook

Edge function `revenuecat-webhook`, deployed with `--no-verify-jwt` (RevenueCat cannot send
a Supabase JWT).

1. `POST` only. Compare the `Authorization` header with `REVENUECAT_WEBHOOK_AUTH` in
   constant time; `401` otherwise.
2. Ignore `event.environment = 'SANDBOX'` in the production project (`200`), unless the
   project is meant for testing.
3. Collect the affected app user ids: `event.app_user_id`, plus `transferred_from` and
   `transferred_to` for `TRANSFER`. Skip ids that are not UUIDs (RevenueCat anonymous
   `$RCAnonymousID:…`).
4. **Do not derive the state from the event type.** Events can arrive late, twice or out of
   order, and a `RENEWAL` processed after an `EXPIRATION` would grant Pro forever. For each
   id, read the truth: `GET https://api.revenuecat.com/v1/subscribers/{id}` with the secret
   key (`REVENUECAT_SECRET_KEY`), take `subscriber.entitlements.pro.expires_date`
   (`null` = lifetime), and write `is_pro = expires_date is null or expires_date > now()`
   with `pro_expires_at`. The same call made twice gives the same row: idempotent.
5. `200` for everything handled or deliberately ignored; `500` only for a real failure, so
   RevenueCat retries. An id that matches no profile is a no-op, not an error.

If the REST call is not possible, the minimum is: grant on `INITIAL_PURCHASE`, `RENEWAL`,
`PRODUCT_CHANGE`, `UNCANCELLATION`, `NON_RENEWING_PURCHASE`, `SUBSCRIPTION_EXTENDED`;
revoke only on `EXPIRATION` (`CANCELLATION` and `BILLING_ISSUE` keep Pro until it expires);
write `event.expiration_at_ms` and ignore events older than `pro_updated_at`.

## Backstop

A daily `pg_cron` job sets `is_pro = false` where `pro_expires_at < now() - interval '1 day'`,
for the webhook that never arrived.

## Manual grants

Test accounts get Pro through a RevenueCat promotional entitlement, not by editing the
column: the next webhook would undo a hand edit, and hand edits make the revenue sanity check
lie. If a row is edited by hand anyway, record it in the app's CLAUDE.md.

## Checks before release

- `select grantee, privilege_type, column_name from information_schema.column_privileges
  where table_name = 'profiles' and column_name = 'is_pro'` shows no `authenticated` /
  `anon` `UPDATE`.
- A signed-in test user's `PATCH` of `is_pro` is rejected.
- RevenueCat dashboard → Integrations → Webhooks → "Send test event" returns `200`.
