# Server-verified Pro

The app's `isPro` is a UI hint. The database decides what a user may do.

## The table

A separate table, not columns on `profiles`: profiles are often readable by other users, and
expiry dates and sandbox flags would leak with them.

```sql
create table public.user_entitlements (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  is_pro     boolean not null default false,
  expires_at timestamptz,            -- null with is_pro = true means no end
  is_sandbox boolean not null default false,
  source     text not null default 'revenuecat',   -- 'revenuecat' | 'manual'
  updated_at timestamptz not null default now()
);
grant select on public.user_entitlements to authenticated;   -- own row only, via the policy
grant select, insert, update, delete on public.user_entitlements to service_role;
alter table public.user_entitlements enable row level security;
create policy entitlements_select_own on public.user_entitlements for select to authenticated
  using (user_id = (select auth.uid()));
-- no insert/update/delete policy and no such grant for clients: only the service role writes
```

- **Only the service role writes it.** The old design (a flag on `profiles` next to a
  per-row "update own profile" policy) let any signed-in user `PATCH {"is_pro": true}`
  through PostgREST, a critical audit finding. With a table of its own there is no client
  write grant to forget when a profile column is added.
- Existing apps that still have `profiles.is_pro`: move it, then drop the column; until then
  keep the `revoke update` / column-wise `grant update` pair on `profiles` and list every new
  column in it.
- Server logic reads the table in `security definer` functions (`check_and_consume_<thing>()`),
  never a flag the client sends. Cap Pro limits instead of making them unlimited: a
  compromised Pro account then costs a bounded amount.
- Gated content (Pro media) in a private bucket served through signed URLs from a function
  that checks `is_pro`, or rows behind an RLS policy that reads the table.

## The webhook

Edge function `revenuecat-webhook`, deployed with `--no-verify-jwt` (RevenueCat cannot send
a Supabase JWT).

1. `POST` only. Compare the `Authorization` header with `REVENUECAT_WEBHOOK_AUTH` in
   constant time; `401` otherwise.
2. Sandbox: apply it while the app is in open testing or store review (testers and reviewers
   buy in sandbox and need Pro). Ignore `event.environment = 'SANDBOX'` only once production
   purchases are the only ones that should count. Store `is_sandbox` either way.
3. Collect the affected app user ids: `event.app_user_id`, plus `transferred_from` and
   `transferred_to` for `TRANSFER`. Skip ids that are not UUIDs (RevenueCat anonymous
   `$RCAnonymousID:…`).
4. **Do not derive the state from the event type.** Events can arrive late, twice or out of
   order, and a `RENEWAL` processed after an `EXPIRATION` would grant Pro forever. For each
   id, read the truth with the v2 secret key (`REVENUECAT_SECRET_KEY`, read-only customer and
   project configuration) and `REVENUECAT_PROJECT_ID`:
   `GET /v2/projects/{project}/entitlements` once to resolve the internal id (`entl…`) of
   lookup key `pro`, then `GET /v2/projects/{project}/customers/{id}/active_entitlements`.
   `expires_at` is epoch ms (`null` = no end); a `404` customer has no Pro. New secret keys
   are v2: the v1 `/subscribers` endpoint rejects them with code 7723. Upsert
   `user_entitlements` with `is_pro = expires_at is null or expires_at > now()` and the end date. The same call made
   twice gives the same row: idempotent.
   If the read fails (missing secret, timeout, non-404 error), fall back to the event-type
   mapping below instead of failing: a purchase must never stay ungranted because of the
   lookup.
   **Restore behaviour:** the RevenueCat project's "restore purchases" setting must be
   "transfer to new App User ID" (the default); the `TRANSFER` handling below assumes it.
   With "keep with original" the purchase never moves and the new uid stays free.
5. `200` for everything handled or deliberately ignored; `500` only for a real failure, so
   RevenueCat retries. An id that matches no profile is a no-op, not an error.

If the REST call is not possible, the minimum is: grant on `INITIAL_PURCHASE`, `RENEWAL`,
`PRODUCT_CHANGE`, `UNCANCELLATION`, `NON_RENEWING_PURCHASE`, `SUBSCRIPTION_EXTENDED`;
revoke only on `EXPIRATION` (`CANCELLATION` and `BILLING_ISSUE` keep Pro until it expires);
write `event.expiration_at_ms` and ignore events older than `updated_at`.

## Backstop

A daily `pg_cron` job sets `is_pro = false` where `expires_at < now() - interval '1 day'`,
for the webhook that never arrived.

## Manual grants

Test accounts get Pro through a RevenueCat promotional entitlement, not by editing the
row: the next webhook would undo a hand edit, and hand edits make the revenue sanity check
lie. If a row is edited by hand anyway, record it in the app's CLAUDE.md.

## Checks before release

- `select grantee, privilege_type from information_schema.role_table_grants
  where table_name = 'user_entitlements'` shows `authenticated` with `SELECT` only and no
  `anon` privilege at all.
- A signed-in test user's `PATCH` / `INSERT` on `user_entitlements` is rejected (42501).
- RevenueCat dashboard → Integrations → Webhooks → "Send test event" returns `200`.
