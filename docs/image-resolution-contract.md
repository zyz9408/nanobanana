# Image Resolution Contract

Image generation keeps separate resolution contracts per model family.

- Gemini image models keep the existing `1K`, `2K`, and `4K` values. These values are passed to `generationConfig.imageConfig.imageSize` together with the selected aspect ratio.
- `gpt-image-2` uses the OpenAI-style `size` field. The selector exposes `auto`, `1K`, `2K`, and `4K`; the `1K`/`2K`/`4K` choices are converted into a concrete `WxH` size from the current aspect ratio.
- The default `gpt-image-2` resolution tier is `1K`.
- `gpt-image-2` calculated sizes must keep both edges as multiples of 16, the maximum edge no more than `3840`, the long-to-short-edge ratio no more than `3:1`, and total pixels from `655360` through `8294400`. Aspect ratios beyond `3:1` are clamped to the API maximum ratio.
- Custom or restored `gpt-image-2` sizes are accepted only when they satisfy the same constraints.
- The front-end resolution selector switches to the GPT values only when the selected image model is exactly `gpt-image-2`.
- OpenAI proxy requests for `gpt-image-2` send `size` and do not send the Gemini-style `aspect_ratio` field.

Source: project gpt-image-2 Generations OpenAPI spec, with the OpenAI Images guide linked by that spec.
