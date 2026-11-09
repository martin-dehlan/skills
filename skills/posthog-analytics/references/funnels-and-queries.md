# Funnels and queries

Most "the event is not firing" reports are a funnel built wrong. Check here before touching
code.

## Reading a funnel

- **Steps are sequential.** Step N counts only people who did step N-1 first, in that
  order, inside the window. An event that fires before an earlier step is invisible.
- **`0 completed / 0 dropped` means nobody arrived.** A step that never fires shows
  `0 completed / N dropped`. Both zero: the funnel ended above it.
- **The window defaults to 14 days.** Signup → purchase or guest → account often takes
  longer; use 30 days there. A single-sitting funnel (paywall impression → CTA → purchase)
  uses 1 day, or a later unrelated impression closes the loop.
- Never put onboarding steps in front of a paywall funnel: the onboarding paywall is one
  `source` of many, the others happen long after onboarding.
- An explicit decline (`paywall_dismissed`) is a trend next to the impression, not a step.
- **"Does the event exist at all?"** → Activity, filter by name, 90 days. Not a funnel.
- Filter `build_mode = release` and exclude store test devices first.

## Querying with HogQL

Most questions are a `group by`, not a funnel. Keep a small read-only script in the app at
`scripts/dev/posthog.py` that posts to `POST /api/projects/<id>/query/` with
`{"query": {"kind": "HogQLQuery", "query": "..."}}` and the **personal** key
(`POSTHOG_PERSONAL_KEY`, scope `query:read`) from `.env.tools`. The ingest key cannot read.

```sql
-- what fires, last 7 days
select event, count() from events
where timestamp > now() - interval 7 day
  and properties.build_mode = 'release'
group by 1 order by 2 desc

-- swallowed failures by kind and cause, distinct people, per app version
select properties.kind, properties.pg_code, properties.$app_version,
       count() as n, count(distinct person_id) as people
from events
where event = 'sync_failed' and timestamp > now() - interval 30 day
group by 1, 2, 3 order by n desc

-- paywall conversion by source
select properties.source,
       countIf(event = 'paywall_viewed') as viewed,
       countIf(event = 'purchase_completed') as bought
from events
where timestamp > now() - interval 30 day
  and properties.build_mode = 'release'
group by 1 order by viewed desc
```

Distinct people beat raw counts for anything retried: one looping device can produce
hundreds of events.

## Store test devices

Apple and Google run every submitted build on their own devices, and those look like real
people. Inferred patterns, not documented by either store:

| Source | Pattern |
|---|---|
| Google Play pre-launch | a handful of fixed `$device_name` values, mostly in release weeks |
| Apple review | `$geoip_city_name = 'Cupertino'`, or `$timezone = 'Asia/Shanghai'` with a US IP; one short day, no content created |

Apple's devices often cannot finish Sign in with Apple or Google (error 1000, "Unable to
open Safari") within milliseconds, and run old builds. Check session depth before calling a
login failure spike real. Record the concrete device names in the app's funnel doc.

## Sanity check against the database

PostHog and Supabase should agree. When they do not, find out which is wrong:

| PostHog | Supabase |
|---|---|
| `guest_session_started` | `count(*) from auth.users where is_anonymous` |
| `guest_converted` | anonymous users whose `is_anonymous` flipped to false |
| `purchase_completed` (with `is_sandbox = false`) | rows in the entitlement table, minus manual test grants |

## Alerts

One alert per thing that would otherwise reach you through a review: login failures
(`sign_in_failed` by more than 2 people a day), terminal sync failures, purchase failures by
`reason`. Name the alert after the symptom, list it in the app's CLAUDE.md.
