---
name: flutter-feature-stack
description: Use before writing or changing any Dart code in a Flutter app on the Riverpod + Freezed + Drift + Supabase stack (lib/, test/, integration_test/), including planning a feature or a fix. Architecture conventions - layers, folders, naming, Riverpod 3, Freezed, Drift local-first sync, go_router, deep links, errors, tests.
---

# Flutter feature stack

Conventions for Flutter apps on Riverpod 3, Freezed, Drift and Supabase. Every rule comes
from code that shipped or from a production bug; the short reasons say which.

**Precedence:** the repo's CLAUDE.md wins over this skill. It lists the app's deviations and,
under **Helpers**, the concrete classes behind the generic names used here ("the app's
network-timeout helper", "the app's error widgets"). Before writing a new file, open one
existing file of the same type and match it.

## Layers

```
Domain (pure Dart) → Data (Supabase / Drift) → Controller (Riverpod) → Presentation
```

| Layer | May import | Never |
|---|---|---|
| domain/ | Dart + freezed_annotation | flutter, riverpod, supabase, `AsyncValue` |
| data/ | domain | controller, presentation |
| application/ (optional) | domain, data | presentation |
| controller/ | domain, data, application | widgets |
| presentation/ | domain, controller | repositories, Supabase client, DAOs |

## Folders and naming

```
lib/
  common/     database/  errors/  l10n/  services/  theme/  utils/  widgets/
  core/       routes/  config/
  features/<feature>/
    domain/        entities/<name>.entity.dart   repositories/<name>.repository.dart
    data/          models/<name>.model.dart   data_sources/<name>.api.dart
                   repositories/<name>.repository.impl.dart   services/ (flushers, uploaders)
    application/   services that orchestrate several repositories or platform APIs
    controller/    <feature>.provider.dart        ← providers AND notifiers
    presentation/  modules/<screen>/<screen>.screen.dart   widgets/<name>.widget.dart
```

- File `name.type.dart` → class `NameType`. Suffixes: `.entity` `.model` `.mapper`
  `.repository` `.repository.impl` `.api` `.service` `.provider` `.screen` `.widget`
  `.table` `.dao` `.routes`. Every new file gets one, common widgets included.
- Drift lives in `lib/common/database/` (`tables/<name>.table.dart`, `daos/<name>.dao.dart`).
- One public widget per file. No `Widget _buildX()` methods: extract a class.
- Limits: widget 300 lines, provider 400, repository/service 300. Over the limit, split
  `controller/` by sub-feature (`item_detail.provider.dart`), never by type. Enforced as a
  ratchet by `check_file_sizes.sh`: a file already over may not grow (`.file-size-baseline`
  lists them; create it with `--update`), and the layer table by `check_layers.sh`.
- No use cases that only forward to a repository. Orchestration goes in `application/`.

## Riverpod 3 (code-gen)

- Always `@riverpod` / `@Riverpod(...)` with `part '<file>.g.dart';`. No hand-written providers.
- `ref.watch` in `build`, `ref.read` in callbacks, `ref.listen` for snackbars and navigation.
- **Anything user-scoped watches the current user id**, directly or through a repository
  provider that does. A `ref.read(repoProvider)` in `build` keeps the previous account's
  stream after an account switch, and the new account sees nothing until a restart.
- **Action controllers** (`void build()`, only called through `ref.read(...notifier)`) are
  `@Riverpod(keepAlive: true)`. Riverpod 3 disposes an unlistened auto-dispose notifier while
  its method is suspended on an `await`, and the next `ref` call throws. Notifiers with real
  state stay auto-dispose and check `ref.mounted` after every `await`.
- `valueOrNull` is gone: `.value` is nullable, `requireValue` throws.
- Errors reach the UI wrapped in `ProviderException`. Unwrap them (the app's unwrap helper)
  before any `is AppError` check or `switch`.
- Failed providers retry automatically. Use the app's retry config instead of a custom loop.
- Use `.select(...)` when a widget needs one field.

```dart
@Riverpod(keepAlive: true)
class ItemsController extends _$ItemsController {
  @override
  void build() {}

  /// Offline-safe: the repository writes Drift first and queues the sync,
  /// so this only throws on a real local failure.
  Future<void> create(ItemEntity draft) async {
    await ref.read(itemRepositoryProvider).create(draft);
    ref.read(analyticsProvider).itemCreated(draft.id);
  }
}

// Screen
Future<void> _submit() async {
  setState(() => _saving = true);
  try {
    await ref.read(itemsControllerProvider.notifier).create(_draft);
    if (mounted) context.go(AppRoutes.item(_draft.id));
  } catch (e) {
    if (mounted) showErrorSnack(context, e);       // the app's snackbar + error mapping
  } finally {
    if (mounted) setState(() => _saving = false);  // a spinner without finally hangs forever
  }
}
```

## Freezed

- Classes are `abstract class X with _$X` (single constructor) or `sealed class X with _$X`
  (union). A plain `class X with _$X` no longer compiles.
- Dart `switch` patterns and the generated `when` / `map` both work (Freezed ≥ 3.1). Follow
  the file you are in.
- Entities: `part '*.freezed.dart'` only. Models: `.freezed.dart` + `.g.dart`, `fromJson`,
  `@JsonKey(name: 'snake_case')`. Mappers are extensions (`ItemModelX.toEntity()`).

## Data

Decide per feature which side is the source of truth and write it in CLAUDE.md:
- **User-owned data → Drift is the truth.** The UI watches Drift; Supabase is the sync target.
- **Served content → Supabase is the truth.** Drift is a read-through cache, never written back.

Tables: `@DataClassName('ItemTableData') class ItemTable extends Table`, text UUID ids,
`userId`, `createdAt`, `updatedAt`, plus `isSynced` / `syncAttempts` for user-written data.
One DAO per table (`@DriftAccessor`); conversions are extensions (`ItemTableDataX.toEntity()`).

Rules for local-first writes. **Read [references/offline-sync.md](references/offline-sync.md)
before changing a repository, DAO, outbox, flusher or media upload.**
1. Saving never waits on the network: write Drift, return, sync afterwards. Offline with an
   expired token, every Supabase call first waits in the auth refresh loop for seconds.
2. Every network call has a timeout (the app's network-timeout helper). A hung call silently
   blocks a single-flight queue for the rest of the session.
3. Every user-written table has `isSynced` + `syncAttempts` and an outbox flusher; without
   them, one failed push strands the write on the device.
4. A pull never overwrites a row with `isSynced = false`.
5. Timestamps go to Supabase as UTC: `dt.toUtc().toIso8601String()`. An offset-less local
   time is stored shifted by the user's UTC offset, and the error grows on every re-save.
6. Drift reads are scoped to the current user id; otherwise an account switch on the same
   device shows the previous user's rows.
7. Schema change: bump `schemaVersion`, add the migration step **and** a migration test from
   the previous version. A broken `onUpgrade` bricks every existing user at once. SQLite
   `ADD COLUMN` cannot take a non-constant default such as `currentDateAndTime`.

## Errors

- Repositories throw `AppError`; the app maps and shows it with its error helpers (see
  CLAUDE.md). Never show `e.toString()`.
- Inside `try`, always `return await future;`. An un-awaited return escapes the `catch`.
  Keep the analyzer at zero warnings; it reports this case.
- Action handlers in the UI: `try` → `catch` (snackbar) → `finally` (clear the spinner).
- Never swallow a sync error: report it to analytics with kind, Postgres code and error
  class. That event is how sync bugs get found at all.

## One action, one entry point

When an action can start from several places (create from a form, a scan, a share; open the
paywall from several CTAs), route every entry through one controller method or helper. When
fixing one path, grep all entry points: a fix applied to one path ships the bug twice.

## Navigation (go_router)

- Paths in `AppRoutes`; the router is a provider; the auth guard lives only in `redirect`.
  Apps where login is optional have no guard.
- Never snapshot auth state in `initState` (`ref.read(isAuthenticatedProvider)`): during
  sign-out it still reads authenticated. Watch it, or decide in `redirect`.
- Every auth transition has a test for where the user lands: sign-out, account deletion,
  guest → new account, guest → existing account. These regress repeatedly otherwise.
- Deep links: `app_links` owns them. Flutter's engine deep linking stays **off**
  (`FlutterDeepLinkingEnabled` = false in Info.plist, `flutter_deeplinking_enabled` = false in
  AndroidManifest), or it races app_links into a 404 on cold start. On cold start, hold the
  splash until the profile is ready, then `go` (not `push`) to the target so nothing flashes
  underneath.
- `context.go` for top level and tabs, `context.push` for drill-down.

## Code-gen

`dart run build_runner build` after every annotation change (`--delete-conflicting-outputs`
is ignored since build_runner 2.15). Generated files are committed and CI fails when they
drift. Never edit `*.g.dart` or `*.freezed.dart`.

## Tests

- New behaviour → tests. Every fix → a regression test that fails before the fix.
- Tests mirror `lib/` paths (the app's CLAUDE.md names the layout); full flows in
  `integration_test/`.
- Unit: `ProviderContainer(overrides: [...])` + `addTearDown(container.dispose)`;
  repositories with mocktail. Test action controllers **without a listener** too.
- Shared fakes and mocks live in `test/helpers/`. Add new ones there, not in the test file.
- Widget tests: the app's pump helper + provider overrides, no real network. Integration
  tests: the whole app with network and platform fakes.
- Always cover: loading ends, the network-error fallback, the error message shown, and
  offline write → reconnect → synced.
- Auth and navigation flows also get a Maestro flow in `e2e/` (see the app-release skill,
  device testing). Every control a flow taps carries `Semantics(identifier: '<area>.<name>')`;
  flows never match localized text.

## Upgrades

After a Flutter, Dart or codegen upgrade, run `flutter test` and one real build.
`flutter analyze` does not compile packages in `.pub-cache`, so a package broken by the new
SDK only fails at build time. A dead package gets vendored under `packages/`.

## Before you say done

```bash
dart format . && flutter analyze && flutter test
bash scripts/check_ui_rules.sh             # when UI files changed
bash scripts/check_layers.sh               # new imports against the layer table
bash scripts/check_file_sizes.sh           # a file over its limit may not grow
python3 scripts/check_claude_helpers.py    # when you renamed or moved a helper
```

After renaming or moving a class listed under **Helpers** in CLAUDE.md, update the table in
the same commit. [`scripts/check_claude_helpers.py`](scripts/check_claude_helpers.py) fails CI
when a name there no longer exists in the code.
