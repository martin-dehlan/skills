---
name: revenuecat-purchases
description: In-app subscriptions with RevenueCat in Flutter apps on Supabase - keys, configure, entitlements and offerings, identity (logIn/logOut with the Supabase uid, guests), the purchase flow and error mapping, trials, purchase telemetry, paywall store rules, and server-verified Pro through a webhook. Use for paywall, Pro gating, subscription screens, purchases_flutter code, or the RevenueCat webhook.
---

# RevenueCat purchases

Every rule comes from code that shipped or a bug found in an audit; the short reasons say
which. The repo's CLAUDE.md wins and names the concrete repository, entitlement and webhook.

## Keys

- The secret key never goes in the bundled `.env`, not even "for now": the next build ships
  it. It belongs in edge function secrets and, for local tools, the tools env file.
- Only the public SDK keys ship: `REVENUECAT_APPLE_KEY` (`appl_…`) and
  `REVENUECAT_GOOGLE_KEY` (`goog_…`) in the bundled `.env`. The secret key (`sk_…`) lives in
  edge function secrets only. `Env` rejects `sk_` **by shape**, not only by name: a secret
  pasted under a public name ships just the same.
- A `test_` key in a **release** build is a fatal error in the SDK (it does not just show a
  warning dialog): never ship it. Guard twice: skip `configure` when the key starts with
  `test_` and the build is release, and fail the release script when `.env` contains
  `test_` (the app-release device-testing steps restore `.env` and compare its checksum).
- No key for this platform → Pro is **unavailable**: nothing is locked, no paywall is shown.
  A paywall nobody can pay at is worse than a free feature. Implement it as a second
  repository (`UnavailableProRepository`), not as `if`s in the UI.

## SDK versions

Read from the apps' `pubspec.lock` on 2026-11-10: `purchases_flutter` 9.16 (sippd) and 11.0
(purelofi), two majors apart. The rules here hold for both; where the API differs, the app's
CLAUDE.md names which major it is on. Upgrade one major at a time and re-run the Test Store
flow.

## Shape

- `ProRepository` interface in `domain/`, `RevenueCatProRepository` in `data/`. The rest of
  the app sees `ProStatus` (`isPro`, `plan`, `expiresAt`, `willRenew`, `manageUrl`) and
  `ProPlan`, never `CustomerInfo` or `Package`.
- One entitlement id, a constant: `pro`. Gate on `entitlements.active['pro']`, never on a
  product id: products change, the entitlement does not.
- The dashboard holds a `current` offering with `annual` and `monthly` packages. Read
  `offering.annual` / `offering.monthly`, do not search by product id.
- Configure once, lazily or in `main()`, then `addCustomerInfoUpdateListener` into a
  broadcast stream. Status is a `Stream<ProStatus>`: current value first, then every
  renewal, expiry, refund or purchase on another device.
- After the user may have changed something in the store (back from "Manage subscription",
  app resume on the subscription screen): `invalidateCustomerInfoCache()` then
  `getCustomerInfo()`. Expiry does not always reach the listener; the SDK keeps serving
  "still active" from cache.
- Debug-only override for UI testing (`--dart-define=FORCE_PRO`), checked under
  `kDebugMode`. Never honoured in release: a re-signed build would unlock Pro for free.

## Identity

- RevenueCat app user id = Supabase `auth.users.id`. That is what lets the webhook find the
  profile and Pro follow the account to other devices.
- `logIn(uid)` at boot for a user already signed in, and on every auth change. `logOut()` on
  sign-out, skipped when `Purchases.isAnonymous` (it throws, code 22, and anonymous is the
  state you want anyway).
- **Guests stay off RevenueCat.** Identifying an anonymous Supabase session mints one RC
  customer per guest. They hit the account gate before the paywall; on conversion the uid
  stays the same and `logIn` merges any anonymous purchase.
- identify/logout run fire-and-forget from the auth listener: catch everything. A failed
  `logIn` means stale entitlements until the next change, never a sign-in error.
- **A purchase waits for the pending `logIn`.** Keep the last identity future and `await`
  it before `purchase()` and `restore()`, or a purchase right after sign-in lands on the
  anonymous id it was replacing.
- Sign-in is required before buying or restoring, so Pro always belongs to an account.

## Purchase flow

- `Purchases.purchase(PurchaseParams.package(p))` returns the new `CustomerInfo`; push it to
  the status stream at once, do not wait for the listener.
- Map `PlatformException` with `PurchasesErrorHelper.getErrorCode`:

| Code | Result |
|---|---|
| `purchaseCancelledError` | outcome `cancelled`: no error shown, no error reported |
| `paymentPendingError` | outcome `pending`: "waiting for approval", Pro arrives via the stream |
| `networkError`, `offlineConnectionError` | `AppError.network` |
| `productAlreadyPurchasedError` | `AppError.purchase` pointing at Restore |
| `purchaseNotAllowedError`, `storeProblemError`, rest | `AppError.purchase` with a plain message |

- Restore returns whether the `pro` entitlement is now active; say "nothing to restore"
  when it is not.
- Trial length: Apple as `introductoryPrice` with price `0`, Google as
  `defaultOption.freePhase`. Show "Try N days free" only when a plan really has one.
- Prices from `storeProduct.priceString` / `pricePerMonthString`, never hardcoded.

## Telemetry

With the posthog-analytics skill. Events: `paywall_viewed` (`source`), `plan_selected`,
`purchase_started`, `purchase_completed`, `purchase_cancelled`, `purchase_pending`,
`purchase_failed` (`reason`), `restore_tapped`, `restore_completed` (`found`). On
`purchase_completed` add, from the returned entitlement: `is_sandbox`, `period_type`
(`trial` / `normal` / `intro`), `store`, `will_renew`. Without them sandbox runs and trial
starts count as paid conversions; one funnel showed eight purchases for one paying
subscriber.

## Store rules on the paywall

Price per period, trial terms and what happens after, Restore purchases, Terms of Use and
Privacy Policy links (App Review 3.1.2). "Manage subscription" opens
`customerInfo.managementURL`. No Google Play wording on iOS. See app-release.

## Server-verified Pro

Client-side gating only hides UI. Anything that costs money (API quotas, scans) or content
that is the product (Pro media) must be checked on the server. Webhook, table and grant
rules: [references/server-entitlement.md](references/server-entitlement.md).

## Tests

- End to end on a simulator with RevenueCat's Test Store: app-release, device testing,
  purchases.
- Pure functions for `statusFrom(CustomerInfo)`, plan period from product id, trial days,
  error-code mapping, telemetry properties.
- The controller with a fake repository: purchase waits for identify; cancelled is not an
  error; unavailable Pro locks nothing.

## Troubleshooting: the paywall is empty or prices do not load

Work down the list; the first failing item is the cause.

1. **Offerings:** RevenueCat dashboard → Offerings has a *current* offering with packages
   attached to products; the app calls `getOfferings()` and logs `current == null`.
2. **Products:** each product exists in the store, has the *same id* in RevenueCat, and its
   state is ready (App Store Connect: "Ready to Submit" or later, with price and
   localization; Play Console: active base plan).
3. **Agreements:** Paid Apps Agreement accepted, tax and banking complete (App Store Connect);
   merchant account set up (Play).
4. **Bundle id / package name** in RevenueCat equals the app's, and the right platform key
   (`appl_` / `goog_`) is configured.
5. **Build:** an App Store build needs a sandbox Apple account on the device; Android needs a
   Play-installed build (internal testing track) with a licence-tester account; a simulator
   with the Test Store (`test_` key) needs no store account.
6. **Cache:** products can take hours after creation; try another device before changing code.
