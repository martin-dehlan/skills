---
paths:
  - "**/lib/**/presentation/**/*.dart"
  - "**/lib/**/widgets/**/*.dart"
  - "**/lib/common/theme/**/*.dart"
  - "**/lib/**/*_screen.dart"
  - "**/lib/**/*_page.dart"
---

# UI rules (loaded when you touch a screen, widget or theme)

Short form of the `lean-flutter-ui` skill. Load the skill for motion, states, text and share cards.

- Colors only from `Theme.of(context).colorScheme`. No `Colors.x` (except `transparent`), no `Color(0x..)` outside `lib/common/theme/`.
- Spacing, padding and font sizes only from the app's responsive tokens. Open `lib/common/utils/responsive.dart` and use its exact getter names. A missing size becomes a new token, not an inline number.
- `TextStyle(...)` only with a token `fontSize` and a `cs` color.
- Screen size via `MediaQuery.sizeOf(context)`, never `MediaQuery.of(context).size`.
- Radius: the app's card radius, never a literal `BorderRadius.circular(n)`.
- Never: gradients, `BackdropFilter`, blur above 10, elevation above 1, more than two nested cards, emoji as icons, decorative icons.
- One title, one supporting line, details. At most one primary and one secondary action.
- Every async view has data, loading (skeleton) and error (with retry). An empty state has exactly one CTA.
- Animations respect the motion setting and `MediaQuery.disableAnimationsOf(context)`; entrances run once.
- After an `await` check `mounted`; reset loading flags in `finally`.
- Check before you say done: `bash scripts/check_ui_rules.sh`.
