# Off-screen renders (share cards, exports)

Read when a widget is rendered to an image instead of the screen.

- They render on a fixed canvas (e.g. 1080 × 1920), so fixed pixel sizes and a fixed palette
  are correct there. List the folder in `.ui-rules-ignore`.
- Wrap the detached tree in `Localizations` (plus Theme and MediaQuery). Otherwise every l10n
  lookup throws off-screen, and release builds export a plain grey image.
- Resolve signed URLs and `precacheImage` before the capture; if a signature fails, render the
  placeholder instead of aborting the share.
