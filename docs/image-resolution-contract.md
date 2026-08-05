# Image Resolution Contract

Image generation keeps separate resolution contracts per model family.

- The balance indicator reads token quota from `https://magic666.top/api/usage/token/` with `Authorization: Bearer <API Key>`, independent of the configured model Base URL. The trailing slash is intentional to avoid a redirect that can drop the `Authorization` header.
- Magic/New API returns raw quota units. The balance indicator converts these using `500000` raw units per displayed `1.00`, matching magic666.top's `quota_per_unit` setting.
- The image model selector is a static list of four visible choices: `Gemini 3 Image Pro`, `Gemini 3.1 Image Fast`, `GPT Image 2`, and `GPT Image 2 Pro (Native 4K)`. Image and video model selectors no longer expose remote model-reading buttons or call model-list endpoints.
- `Gemini 3 Image Pro` (`gemini-3-pro-image-preview`) is the default image model. Removed or stale model selections fall back to this model.
- Gemini image models keep the existing `1K`, `2K`, and `4K` values. These values are passed to `generationConfig.imageConfig.imageSize` together with the selected aspect ratio.
- Gemini image models use the Gemini native `generateContent` payload in both Google native mode and third-party proxy mode. Proxy mode sends the API key through `Authorization: Bearer ...` and does not append a `?key=` query string.
- Image extraction accepts both Gemini native fields and common proxy variants, including `inlineData`, `fileData.fileUri`, OpenAI-style `choices[].message.content`, nested image arrays, Markdown image URLs, direct URLs, and base64 image strings.
- The `gpt-image-2` model family, including `gpt-image-2-pro`, uses the OpenAI-style `size` field. The selector exposes rough `1K`, `2K`, and `4K` tiers; the front end converts the selected tier plus the current aspect ratio into a concrete documented `WxH` size before sending the request. For GPT Image 2 Pro, native 4K is sent as `3840x2160` (landscape) or `2160x3840` (portrait).
- The default `gpt-image-2` family resolution tier is `1K`.
- `gpt-image-2` family backend sizes are limited to the MagicAPI documented set: `1024x1024`, `1536x1024`, `1024x1536`, `2048x2048`, `2048x1152`, `1920x1080`, `1080x1920`, `3840x2160`, and `2160x3840`.
- Custom or restored `gpt-image-2` family sizes are accepted only when they are in that documented set.
- The front-end resolution selector switches to the GPT values only when the selected image model is in the `gpt-image-2` family.
- OpenAI-style image proxy requests for the `gpt-image-2` family send `size` and do not send the Gemini-style `aspect_ratio` field.
- Selecting either GPT Image 2 model automatically switches the UI to the OpenAI-style third-party proxy protocol so it cannot be sent accidentally to a Google native endpoint.
- Gemini proxy requests do not map `2K` and `4K` to alternate model names; the selected model stays in the path and the resolution stays in `generationConfig.imageConfig.imageSize`.

Source: project gpt-image-2 Generations OpenAPI spec, MagicAPI GPT Image 2 Pro generation endpoint, and MagicAPI Gemini native image generation spec.
