const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true, channel: process.env.TEST_BROWSER_CHANNEL || 'chrome' });
    try {
        const page = await browser.newPage();
        page.setDefaultTimeout(10000);
        const errors = [];
        const requests = [];
        const pixel = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4ioAAAAASUVORK5CYII=';
        const imageUrl = 'https://images.example.test/result.png';
        const dataUrl = 'data:image/png;base64,' + pixel;
        let reply = {};
        let replyStatus = 200;
        page.on('pageerror', error => errors.push(error.message));
        page.on('dialog', dialog => { errors.push(dialog.message()); dialog.dismiss(); });
        // Exercise the real UI and request code without spending quota or sending credentials.
        await page.route('https://**/*', async route => {
            const request = route.request();
            if (request.method() === 'POST') {
                requests.push({ url: request.url(), headers: request.headers(), body: request.postDataJSON() });
                await route.fulfill({ status: replyStatus, contentType: 'application/json', body: JSON.stringify(reply) });
            } else if (request.url() === imageUrl) {
                await route.fulfill({ status: 200, contentType: 'image/png', body: Buffer.from(pixel, 'base64') });
            } else {
                await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
            }
        });
        await page.goto(pathToFileURL(path.resolve(__dirname, '../index.html')).href);
        await page.locator('#apiKey').fill('test-key');
        const replies = [
            { content: '![Generated image](' + imageUrl + ')' },
            { content: dataUrl },
            { content: 'Source: https://example.test/not-an-image', images: [{ image_url: { url: imageUrl } }] },
            { content: [{ type: 'text', text: 'Source: https://example.test/not-an-image' }, { type: 'image_url', image_url: { url: dataUrl } }] }
        ];
        for (const model of ['gpt-image-2.5-flare', 'gpt-image-2.5-sunburst']) {
            await page.locator('#apiProtocol').selectOption('google');
            await page.locator('#imageModelName').selectOption(model);
            assert.equal(await page.locator('#apiProtocol').inputValue(), 'openai');
            for (let i = 0; i < replies.length; i++) {
                const withReference = i % 2 === 1;
                await page.evaluate(() => clearImages());
                await page.locator('#apiBaseUrl').fill(i % 2 ? 'https://proxy.example.test/v1/' : 'https://proxy.example.test');
                if (withReference) {
                    await page.locator('#fileInput').setInputFiles({ name: 'reference.png', mimeType: 'image/png', buffer: Buffer.from(pixel, 'base64') });
                    await page.waitForFunction(() => refImages.length === 1);
                }
                await page.locator('#prompt').fill('A colorful poster');
                await page.locator('#aspectRatio').selectOption('16:9');
                await page.locator('#resolution').selectOption('4K');
                reply = { choices: [{ message: replies[i], finish_reason: 'stop' }] };
                await page.locator('#genBtn').click();
                await page.waitForFunction(() => document.querySelector('#status').innerText === 'Success');
                const request = requests.at(-1);
                assert.equal(request.url, 'https://proxy.example.test/v1/chat/completions');
                assert.equal(request.headers.authorization, 'Bearer test-key');
                assert.equal(request.body.model, model);
                assert.equal(request.body.stream, false);
                assert.equal(request.body.messages[0].role, 'user');
                const content = request.body.messages[0].content;
                assert.match(content[0].text, /A colorful poster$/);
                assert.match(content[0].text, /16:9/);
                assert.match(content[0].text, /3840x2160/);
                assert.equal(content.length, withReference ? 2 : 1);
                if (withReference) assert.equal(content[1].image_url.url, dataUrl);
                for (const field of ['prompt', 'image', 'n', 'size', 'response_format']) {
                    assert.equal(field in request.body, false, 'Chat must not carry the Images API field ' + field);
                }
                assert.equal(await page.locator('#resultImg').getAttribute('src'), dataUrl);
            }
            await page.reload();
            assert.equal(await page.locator('#imageModelName').inputValue(), model);
            assert.equal(await page.locator('#apiProtocol').inputValue(), 'openai');
        }
        assert.equal(requests.length, 8);

        // Text-only and upstream failures must surface, without retrying a different endpoint/model.
        await page.locator('#prompt').fill('A colorful poster');
        for (const failure of [
            { status: 200, body: { choices: [{ message: { content: 'No image generated.' } }] }, message: '聊天生图接口未返回图片' },
            { status: 400, body: { error: { message: 'upstream rejected request' } }, message: 'upstream rejected request' }
        ]) {
            const count = requests.length;
            reply = failure.body;
            replyStatus = failure.status;
            await page.locator('#genBtn').click();
            await page.waitForFunction(text => document.querySelector('#textOutput').innerText.includes(text), failure.message);
            assert.equal(requests.length, count + 1);
            assert.equal(requests.at(-1).url, 'https://proxy.example.test/v1/chat/completions');
        }

        // Existing GPT Image 2 models keep using the Images API.
        replyStatus = 200;
        reply = { data: [{ b64_json: pixel }] };
        await page.locator('#apiBaseUrl').fill('https://proxy.example.test');
        for (const model of ['gpt-image-2', 'gpt-image-2-pro']) {
            await page.locator('#imageModelName').selectOption(model);
            await page.locator('#genBtn').click();
            await page.waitForFunction(() => document.querySelector('#status').innerText === 'Success');
            assert.equal(requests.at(-1).url, 'https://proxy.example.test/v1/images/generations');
            assert.equal(requests.at(-1).body.model, model);
        }
        assert.deepEqual(errors, []);
        console.log('GPT Image 2.5 chat browser tests passed: routing, references, image responses, persistence, errors, and existing GPT models.');
    } finally {
        await browser.close();
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
