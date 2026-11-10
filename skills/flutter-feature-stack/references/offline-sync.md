# Offline-first sync

Read this before changing a repository, DAO, outbox table, flusher, pull/merge path or media
upload in an app where Drift is the source of truth. Every rule below was a production bug
first, found through sync-failure telemetry.

## 1. The write path

```
tap Save → validate → write Drift (isSynced: false) → return to the UI
                                  └→ enqueue / trigger the flusher (fire and forget)
```

- Nothing network-bound runs before the local insert: no server-side matching, no resolve
  call, no upload, no session refresh. Offline with an expired token, each Supabase call first
  sits in the auth refresh retry loop (~13 s); three in a row made Save take 40 s.
- Work that needs the server (matching, enrichment, uploads) runs after the insert and
  updates the local row when it lands.
- The Save control is disabled while running and the handler is single-flight, so a double
  tap cannot create two rows.

## 2. Sync state on every user-written table

| Column | Meaning |
|---|---|
| `isSynced` | `false` on every local write, `true` only after the server accepted this version |
| `syncAttempts` | server answers for this version; reset on a new local edit |
| parked / blocked | set when the error is permanent or the attempt budget (e.g. 10) is spent |

Operations that are not row upserts get their own outbox tables (`pending_<entity>_deletes`,
`pending_uploads`, ...). A table without these columns strands writes as soon as one push fails.

## 3. The flusher contract

1. **Parents before children** (item → item notes → note photos). Call order alone is not
   enough: the flusher skips a child whose parent is still unsynced. Pushing a child ahead of
   its parent costs a guaranteed FK error (23503) on every pass.
2. **Single-flight returns the running pass.** A second `flush()` while one is running awaits
   the in-flight `Future`; it never `return`s immediately. The early return silently breaks
   the parent → child ordering.
3. **Every write has a timeout.** With single-flight, one hung request keeps the queue marked
   as running for the life of the process, and it never drains again.
4. **Classify the server's answer:**

   | Answer | Meaning | Action |
   |---|---|---|
   | 23505 unique | permanent | park + report. Exception: a collision on a natural key (one row per user and canonical id) **merges** into the existing server row and re-points the children |
   | 23503 FK, 23514 check, 23502 not null, 42501 RLS, PGRST204 unknown column | permanent | park + report, never retry |
   | timeout, socket, 5xx, 429 | transient | retry with backoff inside the attempt budget |
   | 401 / expired JWT | transient | refresh the session, then retry |

   Retrying a permanent error forever burns battery, buries the real failures in noise and
   still strands the row: one device once sent 93 retries of the same unique violation in
   30 hours.
5. **Triggers:** app start, connectivity → online, after each local write, and a periodic pump.
6. **Report every failure** with kind, Postgres code, error class and attempt number. Without
   that event none of the bugs above would have been found.

## 4. Pull and merge (server → Drift)

The pull contract, as concrete as the flusher contract:

- **A pull never overwrites a local row with `isSynced = false`.** Remote rows land as synced,
  so a blind `insertOnConflictUpdate` both loses the pending edit and marks it synced, and the
  flusher skips it forever. Skip pending rows, or merge field by field.
- **Incremental, with a cursor.** Store `last_pulled_at` per table and user (the server's
  `updated_at` of the newest row received, not the device clock). Ask for
  `updated_at > cursor`, ordered by `updated_at, id`, in pages (e.g. 500); advance the cursor
  only after a page is committed. Never fetch the whole table on every `watch` call: the
  watch reads Drift, the pull runs on its own triggers (start, resume, after a flush, a
  realtime ping).
- **Single-flight and throttled.** One pull per table at a time (later callers await the
  running future), at most one per N seconds unless forced by a pull-to-refresh. A pull has a
  timeout like any network call.
- **Conflicts, two devices:** server `updated_at` decides, last write wins per row. A row that
  is `isSynced = false` locally keeps the local edit; its push then overwrites the server row
  (the server sets `updated_at` with a trigger, never the client). For fields where both
  edits matter (counters, sets, notes), merge per field and say which in the repository doc
  comment. Do not invent a vector clock.
- **Deletes propagate** (see section 5): the server keeps a tombstone (`deleted_at`) for as
  long as the oldest supported app version may still pull, and the pull applies it to synced
  rows only. Without tombstones, reconcile ids: after a full page walk, remove local **synced**
  rows the server no longer lists; never touch `isSynced = false` rows.
- Pulls run per user id; on an account switch, drop the previous (guest) user's local data,
  then resubscribe.

### Sign-out and account deletion with unsynced rows

Never push under the next user: the outbox rows belong to the user id they were written under.
On sign-out, try one bounded flush (timeout); if rows remain, tell the user ("N changes are not
uploaded yet. Sign out anyway?"). On confirm, delete the rows together with the rest of the
user's local data. A flusher always uses the row's own `user_id`, never the current session's.

## 5. Deletes

Postgres cascades, Drift does not (unless the Drift FK declares `onDelete: cascade`). Deleting
a parent deletes its local children and queues their server deletes and file removals in the
same transaction. Orphaned child rows otherwise fail with 42501 for weeks.

## 6. Media

- A picked or captured file is copied into application support (the app's pending-media
  store) before it is queued. The picker hands back a file in the cache or tmp directory,
  which the OS may purge before the outbox drains, and then the photo is lost for good.
- The server stores **storage object paths** (`<uid>/<id>.jpg`): never a device path, never a
  public or signed URL.
- Rendering resolves the path through the app's signed-URL image widget and shows a cached
  copy while the signature loads. Off-screen renders resolve and precache first.

## 7. Timestamps and nulls

- Send UTC: `dt.toUtc().toIso8601String()`. Postgres reads an offset-less value as UTC, and
  because Drift hands back a local `DateTime`, the error grows by the UTC offset on every
  re-save.
- In the mapper, coalesce nullable entity fields that are `NOT NULL` on the server
  (`occurredAt ?? createdAt`), or the upsert fails with 23502.

## 8. Tests for every sync change

- Offline create → flusher run → row synced, and the UI never waited on the network.
- A permanent code parks the row after one answer; a transient one retries within budget.
- Child pushed only after its parent; a second `flush()` awaits the first.
- Pull with a pending local edit keeps the edit and its `isSynced = false`.
- Pull with a cursor: second pull asks only for newer rows; a page that fails midway does not advance the cursor; two parallel calls make one request.
- Row deleted on the server disappears locally if synced, stays if `isSynced = false`.
- Sign-out with unsynced rows warns, and the next user never receives them.
- Delete removes local children and queues the server deletes.
- New sync columns: migration test from the previous schema version.
