# Migrations and deploys

Read before writing or applying a migration, changing an RPC or an edge function signature,
or touching grants, policies, triggers or buckets.

## Why this is different from a web app

Every app version still installed hits the same database at the same time. A store release
takes days to roll out and some users never update. There is no per-version API, so the
schema must keep working for the **oldest** version you have not retired.

## 1. Classify every change

| Additive: ship any time | Destructive: expand → migrate → contract |
|---|---|
| new table | drop or rename a table or column |
| new nullable column, or one with a constant default | change a column type, add `NOT NULL` to an existing column |
| new RPC, new optional RPC parameter | change or remove an RPC parameter or its return shape |
| a policy that allows more | a policy that allows less |
| new bucket | make a public bucket private |

Never add and drop in the same deploy.

## 2. Expand → migrate → contract

1. **Expand:** add the new shape next to the old one (new column, new RPC, dual-write
   trigger). Old clients keep working.
2. **Migrate:** backfill; ship a client that writes both and reads the new shape.
3. **Adoption gate:** check in analytics which app versions are still active. Raise the
   minimum supported version (force-update gate) until the old versions are gone.
4. **Contract:** drop the old shape in a separate, later migration.

Example, making media private: path columns + backfill → signing function deployed dormant →
client that reads paths ships → adoption → only then the buckets go private. Flipping first
breaks every image in every older build at once.

## 3. Rules for SQL and server code

- No `SELECT *` and no positional `INSERT INTO t VALUES (...)` in functions, triggers or edge
  functions: both break silently when a column is added.
- No hardcoded project URLs. Functions that call edge functions through `pg_net` read the URL
  per environment (vault or a config table); otherwise the dev project calls prod.
- `security definer` functions: `set search_path = ''`, schema-qualified names, ownership
  checks inside.
- `.insert().select()` in one call evaluates the SELECT policy on the INSERT's snapshot. If the
  policy depends on rows an AFTER INSERT trigger writes (a membership row), the new row is
  invisible and the call fails with 42501. Split it into insert, then select.

## 4. Grants vs RLS

- `42501 permission denied for table` → a missing **GRANT**; RLS never even ran.
- `new row violates row-level security policy` → a **policy** problem (or, for storage
  uploads, a missing SELECT policy, see the main skill).
- Keep the default privileges that grant DML on new `public` tables to `authenticated` and
  `service_role`; tighten access with RLS, never by revoking grants in a "hardening"
  migration. `service_role` also needs the table GRANT before its RLS bypass applies, so edge
  functions break too when grants go missing. Network-only flows show it first; flows backed
  by a local cache hide it.

## 5. Triggers, cron and pg_net

- Push and webhook triggers can disappear without any error after a baseline change. After
  any baseline or large migration, verify them:
  `select tgname, tgrelid::regclass from pg_trigger where not tgisinternal;`
- `pg_net` responses and `cron.job_run_details` grow without bound. Keep a housekeeping job
  that trims them, and gate crons that only make sense in prod.

## 6. How to test a migration

1. Locally: `supabase db reset` (applies every migration from scratch), then the RLS tests in
   `supabase/tests/`.
2. On a Supabase branch or a staging project before prod. The Supabase MCP can create a branch.
3. Apply to prod, then run the security and performance advisors and fix what they report.
4. Risky change (backfill, policy tightening): take a backup first and write down the rollback.

## 7. Migration PR checklist

- [ ] Additive, or the expand step of a planned expand/contract
- [ ] RLS enabled + policies for every new table; RLS tests added
- [ ] No `SELECT *`, no positional INSERT, no hardcoded URLs
- [ ] Drift mirror + `schemaVersion` + migration test updated (if mirrored)
- [ ] Old app versions keep working (state the oldest version you checked against)
- [ ] Advisors clean after applying
