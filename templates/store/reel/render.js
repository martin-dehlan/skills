// node render.js <slide.html> <outdir> <seconds> [fps]
// Steps the slide's render(t) frame by frame and writes one JPEG per frame.
// Needs playwright-core; CHROME points at a Chromium or headless shell binary
// (e.g. ~/Library/Caches/ms-playwright/chromium_headless_shell-<n>/chrome-mac/headless_shell).
const {chromium} = require('playwright-core');
(async () => {
  const [html, out, secs, fps = '30'] = process.argv.slice(2);
  const b = await chromium.launch({executablePath: process.env.CHROME, args: ['--allow-file-access-from-files']});
  const p = await b.newPage({viewport: {width: 1320, height: 2868}});
  await p.goto('file://' + html);
  await p.evaluate(() => document.fonts.ready);
  const n = Math.round(+secs * +fps);
  for (let f = 0; f < n; f++) {
    await p.evaluate(async t => { render(t); await settle(); }, f / +fps);
    await p.screenshot({path: `${out}/${String(f).padStart(4, '0')}.jpg`, type: 'jpeg', quality: 92});
  }
  await b.close();
})();
