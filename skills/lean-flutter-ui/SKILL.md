---
name: lean-flutter-ui
description: Lean Flutter UI conventions - theme colors, responsive spacing tokens, anti-AI-slop, motion values, skeleton loading, offline states, text and i18n layout, off-screen renders. Use when building or changing any screen, widget, animation, loading state or share card in a Flutter app.
paths: "lib/**/presentation/**, lib/common/widgets/**, lib/common/theme/**, lib/common/utils/responsive.dart, lib/core/routes/**"
---

# Lean Flutter UI

Principle: **less, but finished.** Fewer elements, each calm, aligned and animated with
intent. When unsure, remove instead of adding. App-specific names (tokens, widgets, motion
setting) are listed under **Helpers** in the repo's CLAUDE.md.

The rules are strict and CI enforces them on **added lines** (see Enforcement). Old code that
breaks them is fixed only when you touch that widget anyway.

## Always

- Colors only from `Theme.of(context).colorScheme` (`cs`). No `Colors.x` (except
  `Colors.transparent`), no `Color(0x..)` outside `lib/common/theme/`.
- Spacing, padding and font sizes only from the app's `ResponsiveContext` extension in
  `lib/common/utils/responsive.dart`. **Open that file and use its exact getter names**; they
  differ between apps. Never invent a getter. A missing size becomes a new token in that
  file, not an inline number.
- `TextStyle(...)` is fine when `fontSize` is a token and `color` comes from `cs`.
- Read the screen size with `MediaQuery.sizeOf(context)`, not `MediaQuery.of(context).size`:
  it rebuilds only on size changes, not on every keyboard or inset change.
- Hierarchy: one title, one supporting line, details. At most one primary and one secondary
  action per screen.
- Every async view has three finished states: data, loading (skeleton), error (with retry).
  Empty states have exactly one CTA.

## Never (AI slop)

Gradients of any kind · `BackdropFilter` and glassmorphism · blur > 10 · elevation > 1 ·
more than two nested card levels · radius above the app's card radius · emoji as icons ·
decorative icons without a function · more than two buttons competing for attention. A flat
scrim (`cs.scrim` with opacity) over photos or video is fine; a gradient scrim is not.

## Motion

| Use | Duration | Curve |
|---|---|---|
| State change (`AnimatedContainer`, `AnimatedSize`, selection, toggles) | 180–220 ms | `easeOut` |
| Page push (slide from the right) | 320 ms in / 260 ms out | `easeOutCubic` / `easeInCubic` |
| Detail screen entrance (fade + slide up 6 %) | 500 ms | `easeOutCubic` |
| Content entrance (`flutter_animate` `.fadeIn`) | 320–420 ms | `easeOutCubic` |
| List stagger | `delay: i * 60 ms`, capped at 8 items | `easeOutCubic` |
| Section stagger on one screen | 80 / 160 / 240 ms delays | `easeOutCubic` |
| Value count-up, bar fill | 500 ms | `easeOutCubic` |
| Celebration only (achievement unlock, paywall hero) | — | `easeOutBack` allowed |

- One approach per kind: `flutter_animate` for entrances and values, implicit `Animated*`
  widgets for state changes, one shared `CustomTransitionPage` in the router for pages. Write
  an `AnimationController` only for what `flutter_animate` cannot do.
- Every animation respects the app's motion setting (off → jump to the end state) and the OS
  setting `MediaQuery.disableAnimationsOf(context)`.
- Entrances run once, keyed by the item id, never on every rebuild.
- No overshoot, bounce or loop outside celebration moments and real progress.

## Loading, offline, submitting

- First load: skeletons shaped like the real content. No full-screen centered spinner.
- Skeletons are static for "no data" and a slow opacity pulse for "loading". No shimmer: it is
  a gradient. The pulse stops when motion is off.
- Skeleton → content: `AnimatedSwitcher`, 220 ms, `easeOut`.
- **Skeletons end.** After the timeout show the offline or error state, never an endless
  skeleton.
- Refresh with data on screen keeps the data and shows subtle progress. Never blank the screen.
- A control that needs the network says so ("needs internet") instead of spinning; pickers
  have an offline state.
- Submit buttons show inline progress, are disabled while running, and the handler is
  single-flight so a double tap cannot create two rows.
- **A spinner waits only for the answer that decides the next state.** Follow-up work after
  that answer (token or device registration, uploads, sync, prefetch, analytics) runs in the
  background and is never awaited by the UI. A retry or polling loop behind a button makes
  every tap wait the loop's worst case. A permission sheet closes on the OS answer, not on
  what the permission later unlocks.

## Text and languages

- Design for the longest locale (usually German) and 1.3× system text. Every text inside a
  fixed-size box gets `maxLines` + `overflow: TextOverflow.ellipsis`.
- Never use soft hyphens (U+00AD): Flutter draws them as a visible space. Long titles in tight
  grids use the app's hyphenation widget, or a shorter or explicitly hyphenated translation.
- All copy comes from l10n (`AppLocalizations`), including snackbars and error messages. Push
  notifications are rendered in the recipient's language on the server.

## Off-screen renders (share cards, exports)

- They render on a fixed canvas (e.g. 1080 × 1920), so fixed pixel sizes and a fixed palette
  are correct there. List the folder in `.ui-rules-ignore`.
- Wrap the detached tree in `Localizations` (plus Theme and MediaQuery). Otherwise every l10n
  lookup throws off-screen, and release builds export a plain grey image.
- Resolve signed URLs and `precacheImage` before the capture; if a signature fails, render the
  placeholder instead of aborting the share.

## Widget shape

```dart
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item});
  final ItemEntity item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(context.m),             // token names: see responsive.dart
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(context.w * 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: context.headingFont)),
          SizedBox(height: context.xs),
          Text(item.subtitle,
              style: TextStyle(fontSize: context.captionFont, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
```

## Enforcement

[`scripts/check_ui_rules.sh`](scripts/check_ui_rules.sh) checks only lines added since the
base branch, so old code never blocks a PR. Every app keeps a copy at `scripts/check_ui_rules.sh`
and runs it in CI on pull requests (checkout with `fetch-depth: 0`):

```yaml
      - name: ui rules (added lines only)
        if: github.event_name == 'pull_request'
        run: bash scripts/check_ui_rules.sh origin/${{ github.base_ref }}
```

Exceptions:
- `.ui-rules-ignore` at the repo root: one git pathspec per line, for code that legitimately
  uses fixed pixels (e.g. `lib/features/<feature>/presentation/cards/*` for share cards).
- `// ui-rules-ok: <reason>` on the line itself, for a single justified case (the reason is
  required). Prefer a theme color or a new token over the marker.

## Pre-flight

- [ ] `bash scripts/check_ui_rules.sh` passes
- [ ] No `_build*` methods; widget file ≤ 300 lines
- [ ] Data, loading, offline and error states all designed; skeletons end
- [ ] Animations use the table values and respect the motion setting and reduce-motion
- [ ] Copy from l10n; checked in German and at large system text; no soft hyphens
- [ ] Checked on a small phone (≤ 700 pt high)
