# Push notifications (Firebase Cloud Messaging)

Firebase is used for push only. Read before touching tokens, permission prompts or sending.

## Tokens

- Table `push_tokens(user_id, token, platform, updated_at)`, unique on `token`, RLS: owner
  insert/update/delete own rows, no select needed beyond own. Server reads with the secret key.
- Registering a token is **background work**: single-flight (one in-flight future, later calls
  await it), with a timeout, retried on the next app start, never awaited by the UI or by
  login. A slow FCM call must not hold up sign-in.
- Re-register on `onTokenRefresh` and after login (the user id changes). On sign-out delete the
  row for this device, otherwise the next user on the device gets the previous user's pushes.

## Permission

- Ask at a moment with context (after the first saved item, not at launch), with one own
  explainer sheet first. Call the OS prompt from the sheet's button.
- Close the sheet on the OS answer, not on a timer, and handle "denied": hide the toggle's
  promise and offer a link to system settings. iOS asks once.
- Android 13+ needs the `POST_NOTIFICATIONS` runtime permission.

## Sending

- From an edge function, triggered by a database webhook, `pg_net` trigger or cron. Verify the
  shared secret of the trigger in the function.
- Localize on the server from the user's stored language, never ship raw keys to the client.
- Payload carries a deep link (`data: {route: "/item/<uuid>"}`); the app validates it like any
  deep link (see account-lifecycle, section 5) and uses the cold-start rules from the
  flutter-feature-stack skill.
- Delete tokens that FCM reports as `UNREGISTERED`.

## Setup

- iOS: APNs auth key (.p8) uploaded to Firebase; capability Push Notifications and Background
  Modes > Remote notifications in the Xcode project.
- Android: `google-services.json` from the Firebase project, notification channel created at start.
- After a baseline or large migration verify the push triggers still exist:
  `select tgname, tgrelid::regclass from pg_trigger where not tgisinternal;`
