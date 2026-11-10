---
paths:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/*.gr.dart"
  - "**/lib/**/generated/**"
---

# Generated files

Never edit these by hand. Change the source (`@riverpod`, `@freezed`, Drift table) and run
`dart run build_runner build`. A merge conflict in a generated file is resolved by regenerating.
