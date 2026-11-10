-- Template for a user-owned table. One file: table, grants, RLS, policies.
-- Replace "items" and the columns. Delete what the table does not need.

create table public.items (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default (select auth.uid()) references auth.users (id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 200),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- every column a policy filters on is indexed
create index items_user_id_idx on public.items (user_id);

-- Grants: least privilege, per role. No truncate, no references.
grant select, insert, update, delete on public.items to authenticated;
grant select, insert, update, delete on public.items to service_role;
-- grant usage, select on sequence public.items_id_seq to authenticated;   -- only for serial/bigserial ids

alter table public.items enable row level security;

-- Guests are `authenticated` too (anonymous sessions); add `and not (select auth.jwt() ->> 'is_anonymous')::boolean`
-- to a policy that must exclude them.
create policy items_select_own on public.items for select to authenticated
  using (user_id = (select auth.uid()));
create policy items_insert_own on public.items for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy items_update_own on public.items for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy items_delete_own on public.items for delete to authenticated
  using (user_id = (select auth.uid()));

-- Server-only table instead: skip the authenticated grant and the policies,
-- keep `enable row level security`, grant to service_role only.
