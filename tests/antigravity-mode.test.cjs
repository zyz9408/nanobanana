const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true, channel: process.env.TEST_BROWSER_CHANNEL || 'chrome' });
    try {
        const page = await browser.newPage();
        const errors = [];
        const requests = [];
        page.on('pageerror', error => errors.push(error.message));
        page.on('dialog', dialog => { errors.push(dialog.message()); dialog.dismiss(); });
        let releaseFirst;
        const firstResponse = new Promise(resolve => { releaseFirst = resolve; });
        const pixel = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4ioAAAAASUVORK5CYII=';
        // Block all real network calls, including the unrelated quota endpoint.
        await page.route('https://**/*', async route => {
            const request = route.request();
            if (request.method() === 'POST') {
                requests.push({ url: request.url(), headers: request.headers(), body: request.postDataJSON() });
                if (requests.length === 1) await firstResponse;
                await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ candidates: [{ content: { parts: [{ inlineData: { mimeType: 'image/png', data: pixel } }] } }] }) });
            } else {
                await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
            }
        });
        const file = path.resolve(__dirname, '../index.html');
        await page.goto(pathToFileURL(file).href);
        await page.locator('#apiProtocol').selectOption('antigravity');
        assert.equal(await page.locator('#apiKey').isVisible(), false);
        assert.equal(await page.locator('#apiBaseUrl').isVisible(), false);
        assert.equal(await page.locator('#imageModelName').isVisible(), false);
        assert.match(await page.locator('#antigravityNotice').innerText(), /Gemini 3\.1 Flash Image/);
        await page.locator('#prompt').fill('123');
        await page.locator('#genBtn').click();
        await page.waitForFunction(() => document.querySelector('#status').innerText.includes('Thinking'));
        await page.locator('#genBtn').click();
        // Change the UI while both requests are in flight/queued.
        await page.locator('#apiProtocol').selectOption('google');
        await page.locator('#apiKey').fill('manual-test-key');
        await page.locator('#apiBaseUrl').fill('https://manual.example');
        releaseFirst();
        await page.waitForFunction(() => document.querySelector('#status').innerText === 'Success' && document.querySelector('#genBtn').innerText.includes('生成图片'));
        assert.equal(requests.length, 2);
        for (const request of requests) {
            assert.equal(new URL(request.url).pathname, '/v1beta/models/gemini-3.1-flash-image:generateContent');
            assert.notEqual(new URL(request.url).hostname, 'manual.example');
            assert.match(request.headers.authorization, /^Bearer sk-ag-/);
            assert.equal(request.body.generationConfig.imageConfig.imageSize, '2K');
            assert.match(request.body.contents[0].parts[0].text, /^Generate an image/);
            assert.match(request.body.contents[0].parts[0].text, /Description:\n123$/);
            assert.match(request.body.systemInstruction.parts[0].text, /Output ONLY the generated image/);
        }
        assert.equal(await page.locator('#resultImg').isVisible(), true);
        assert.equal(await page.evaluate(() => localStorage.getItem('gemini_api_key')), 'manual-test-key');
        assert.equal(fs.readFileSync(file, 'utf8').includes(requests[0].headers.authorization.slice(7)), false);
        await page.locator('#apiProtocol').selectOption('antigravity');
        await page.reload();
        assert.equal(await page.locator('#apiProtocol').inputValue(), 'antigravity');
        assert.equal(await page.locator('#apiKey').isVisible(), false);
        await page.locator('#apiProtocol').selectOption('openai');
        assert.equal(await page.locator('#apiKey').inputValue(), 'manual-test-key');
        assert.equal(await page.locator('#apiBaseUrl').inputValue(), 'https://manual.example');
        await page.locator('#imageModelName').selectOption('gpt-image-2');
        await page.locator('#apiProtocol').selectOption('antigravity');
        await page.reload();
        assert.equal(await page.locator('#apiProtocol').inputValue(), 'antigravity');
        assert.equal(await page.locator('#resolution option').first().innerText(), '1K (Standard)');
        assert.deepEqual(errors, []);
        if (process.env.TEST_SCREENSHOT) await page.screenshot({ path: process.env.TEST_SCREENSHOT, fullPage: true });
        console.log('Antigravity browser tests passed: empty credentials, fixed model, queue isolation, persistence, encrypted source, original modes.');
    } finally {
        await browser.close();
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
