# 反重力模式

在 API 模式中选择“反重力”，填写图片提示词后点击“生成图片”。无需填写域名或 API Key，可继续使用参考图、画幅、分辨率和图片队列。

此模式固定使用服务端 `/v1/models` 返回的唯一图片模型 `gemini-3.1-flash-image`，界面显示为 Gemini 3.1 Flash Image。使用 Gemini `generateContent` 请求格式和 Bearer 认证。其他模式保留原有模型选择和手填配置，切换模式不会覆盖用户保存的配置。

域名和密钥以 AES-256-GCM 密文内置在 `index.html` 中，运行时通过 Web Crypto 解密。无需后端，可直接打开本地文件，或部署在 HTTPS 静态网站上；本地 HTTP 调试请使用 localhost。

这是静态网页的混淆保护，不是服务端密钥保管：解密材料随网页分发，使用者能从浏览器请求中提取凭据。解密后的配置不会写入 localStorage 或图片历史，也不会用于原有第三方余额查询。需要真正隐藏密钥时，必须改为服务端代理。

每个图片任务在入队时固定 API 模式及手填配置，避免队列执行期间切换模式导致请求发错地址。反重力目前仅用于图片生成，视频页面会提示切换到其他模式。

验证：`powershell -ExecutionPolicy Bypass -File tests/resolution-contract.test.ps1`；安装 Playwright 后执行 `node tests/antigravity-mode.test.cjs`。交互测试会拦截生图请求，不消耗真实额度。
