---
paths:
  - "**/supabase/migrations/**"
---

# Migration rules (loaded when you touch a migration)

Short form of the `supabase-app-backend` skill. Load the skill and its migrations reference before writing one.

- New timestamped file. Never edit, squash or re-baseline a migration that ran on prod.
- A new table gets `enable row level security`, its policies and its explicit `grant`s to the roles that need it, all in this same migration.
- Server-only table: RLS on, no client policy, grant to `service_role` only.
- Never `revoke` existing grants in a "hardening" migration; tighten with RLS.
- Policies use `(select auth.uid())`. Every column a policy filters on has an index. Guests are `authenticated` too.
- `security definer` functions: `set search_path = ''`, schema-qualified names.
- Additive only: add columns nullable or with a constant default. Old app versions keep working until the next release; drop or rename in a later migration.
- Storage: an upload needs a SELECT policy as well as INSERT.
- No secrets, keys or real emails in a migration.
