# Verifying a visible change: three tiers

Use the cheapest tier that can show the failure. A copy or layout change is verified at tier 1
or 2, without a build.

| Change | Tier |
|---|---|
| copy, spacing, colors, layout, a widget's states (loading, empty, error) | 1 |
| animation, scrolling, theme switch, text scale, a screen's feel | 2 |
| login, deep links, permissions, push, purchases, `ios/` / `android/` config, native plugins, a release | 3 |

## Tier 1: golden shot of the widget (seconds)

- Pump the widget with the app's pump helper, fakes and overrides, in the states that matter
  (data, loading, error, long German text, text scale 1.3, a narrow and an 800 dp wide surface).
- Write a PNG (`matchesGoldenFile`, or `RepaintBoundary.toImage` into `build/shots/`) and
  **open the image and look at it**. A passing golden that nobody looked at proves nothing.
- Commit goldens only for stable, high-value widgets; shots for one-off looks stay in `build/`.

## Tier 2: running app, hot reload, screenshot

- Use the Dart and Flutter MCP server (`dart mcp-server`): launch the app on a simulator or
  emulator, `hot reload` after each edit, read the runtime errors, take a screenshot, look at
  it. The app keeps running between edits, so there is no build per change.
- Stay on one debug session; do not start a second build to "check again".

## Tier 3: Maestro on a fresh build

- Flows, native configuration and releases need a real build: see the app-release skill,
  device testing. Run the flows, not a screenshot.
- Build once per question. Reuse the last build when only Dart changed and hot reload is
  possible; rebuild when native files, plugins or env files changed.

## Disk

Builds are large. Before a tier-3 run check free space (`df -h /`); below 15 GB run
`flutter clean` in worktrees you no longer use and delete old `build/` folders and simulator
runtimes that are not needed. Reuse one build per branch; never leave a release APK per
commit lying around. Artifacts stay in the app's `build/` directory, not in the repo root.
