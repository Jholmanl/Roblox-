const { chromium } = require('playwright');
(async () => {
  const [,, url, outPrefix, mapIdx, views] = process.argv;
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  page.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
  page.on('pageerror', e => console.log('pageerror:', e.message));
  await page.goto(url);
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 120000 });
  await page.evaluate(i => window.preview.load(+i), mapIdx);
  for (const v of views.split(',')) {
    await page.evaluate(v => window.preview.setView(+v), v);
    await page.waitForTimeout(1500);
    await page.screenshot({ path: `${outPrefix}_${v}.png` });
  }
  await browser.close();
})();
