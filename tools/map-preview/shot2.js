const { chromium } = require('playwright');
// usage: node shot2.js url mapIdx out.png px py pz tx ty tz [w h]
(async () => {
  const a = process.argv;
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: +(a[12] || 1280), height: +(a[13] || 720) } });
  page.on('pageerror', e => console.log('pageerror:', e.message));
  await page.goto(a[2]);
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 120000 });
  await page.evaluate(i => window.preview.load(+i), a[3]);
  await page.addStyleTag({ content: '.hud,.hint{display:none!important}' });
  const shots = JSON.parse(a[4]);
  for (const s of shots) {
    await page.evaluate(c => window.preview.look(...c), s.cam);
    await page.waitForTimeout(2500);
    await page.screenshot({ path: s.out, timeout: 180000 });
  }
  await browser.close();
})();
