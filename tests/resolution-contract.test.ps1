$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$IndexPath = Join-Path $RepoRoot 'index.html'
$Html = Get-Content -Raw -LiteralPath $IndexPath

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-OptionValues {
    param([string]$ConstantName)

    $pattern = 'const\s+' + [regex]::Escape($ConstantName) + '\s*=\s*Object\.freeze\(\[(?<block>[\s\S]*?)\]\);'
    $match = [regex]::Match($Html, $pattern)
    Assert-True $match.Success "Missing $ConstantName"

    return @(
        [regex]::Matches($match.Groups['block'].Value, 'value:\s*"([^"]+)"') |
            ForEach-Object { $_.Groups[1].Value }
    )
}

function Get-StringArrayValues {
    param([string]$ConstantName)

    $pattern = 'const\s+' + [regex]::Escape($ConstantName) + '\s*=\s*Object\.freeze\(\[(?<block>[\s\S]*?)\]\);'
    $match = [regex]::Match($Html, $pattern)
    Assert-True $match.Success "Missing $ConstantName"

    return @(
        [regex]::Matches($match.Groups['block'].Value, '"([^"]+)"') |
            ForEach-Object { $_.Groups[1].Value }
    )
}

function Assert-Sequence {
    param(
        [string[]]$Actual,
        [string[]]$Expected,
        [string]$Name
    )

    Assert-True ($Actual.Count -eq $Expected.Count) "$Name count mismatch. Expected $($Expected.Count), got $($Actual.Count)."

    for ($i = 0; $i -lt $Expected.Count; $i++) {
        Assert-True ($Actual[$i] -eq $Expected[$i]) "$Name item $i mismatch. Expected '$($Expected[$i])', got '$($Actual[$i])'."
    }
}

Assert-Sequence `
    -Actual (Get-OptionValues 'GEMINI_RESOLUTION_OPTIONS') `
    -Expected @('1K', '2K', '4K') `
    -Name 'Gemini resolution options'

Assert-True `
    ($Html -notmatch 'gemini-2\.5-flash-image') `
    'Gemini 2.5 Flash Image must be removed from the application.'

Assert-True `
    ($Html -match '<option\s+value="gemini-3-pro-image-preview"\s+selected>Gemini 3 Image Pro</option>') `
    'Static model selector must use Gemini 3 Image Pro as the default.'

Assert-True `
    ($Html -match '<option\s+value="gemini-3\.1-flash-image-preview">Gemini 3\.1 Image Fast</option>') `
    'Static model selector must include Gemini 3.1 Image Fast.'

Assert-True `
    ($Html -match '<option\s+value="gpt-image-2">GPT Image 2</option>') `
    'Static model selector must include GPT Image 2.'

Assert-True `
    ($Html -match '<option\s+value="gpt-image-2-pro">GPT Image 2 Pro \(Native 4K\)</option>') `
    'Static model selector must include GPT Image 2 Pro with native 4K support.'

Assert-Sequence `
    -Actual (Get-OptionValues 'GPT_IMAGE_2_RESOLUTION_OPTIONS') `
    -Expected @('1K', '2K', '4K') `
    -Name 'gpt-image-2 resolution options'

Assert-Sequence `
    -Actual (Get-StringArrayValues 'GPT_IMAGE_2_ALLOWED_SIZES') `
    -Expected @('1024x1024', '1536x1024', '1024x1536', '2048x2048', '2048x1152', '1920x1080', '1080x1920', '3840x2160', '2160x3840') `
    -Name 'gpt-image-2 documented backend sizes'

Assert-True `
    ($Html -match 'function\s+isValidGptImage2Size\(size\)') `
    'gpt-image-2 must validate documented backend size values.'

Assert-True `
    ($Html -match 'function\s+normalizeGptImage2Resolution\(resolution,\s*aspectRatio\)') `
    'gpt-image-2 must convert rough resolution tiers and aspect ratio into a concrete backend size.'

Assert-True `
    ($Html -match 'function\s+isGeminiImageModel\(model\)') `
    'Gemini image models must be detected separately from OpenAI-style image models.'

Assert-True `
    ($Html -match 'function\s+buildGeminiImagePayload\(prompt,\s*refs,\s*aspectRatio,\s*resolution') `
    'Gemini image requests must use a shared native payload builder.'

Assert-True `
    ($Html -notmatch '读取模型|fetchModels\s*\(') `
    'Model selectors must be static and must not expose remote model-reading controls.'

Assert-True `
    ($Html -match "isGptImage2Model\(imageModelInput\.value\)\s*&&\s*apiProtocolInput\.value\s*!==\s*'openai'[\s\S]*?apiProtocolInput\.value\s*=\s*'openai'") `
    'Selecting either GPT Image 2 model must route the UI to the OpenAI-style proxy protocol.'

Assert-True `
    ($Html -match 'const\s+MAGIC_TOKEN_USAGE_URL\s*=\s*"https://magic666\.top/api/usage/token/";') `
    'Token quota display must read from magic666.top token usage endpoint without a redirect.'

Assert-True `
    ($Html -match 'const\s+MAGIC_QUOTA_PER_UNIT\s*=\s*500000;') `
    'Token quota display must convert New API raw quota units to Magic display amounts.'

Assert-True `
    ($Html -match 'fetch\(MAGIC_TOKEN_USAGE_URL,\s*\{[\s\S]*?''Authorization'':\s*`Bearer \$\{apiKey\}`') `
    'Token quota display must use Bearer authorization with the current API key.'

Assert-True `
    ($Html -match 'getMagicTokenAvailableQuota\(usage\)') `
    'Token quota display must read the New API token usage available quota.'

Assert-True `
    ($Html -match 'GPT_IMAGE_2_SIZE_BY_RESOLUTION_AND_ASPECT') `
    'gpt-image-2 must keep frontend resolution tiers separate from concrete backend sizes.'

Assert-True `
    ($Html -match "if\s*\(isGptImage2Model\(model\)\)\s*return\s*'1K';") `
    'gpt-image-2 default resolution tier must be 1K.'

Assert-True `
    ($Html -match 'if\s*\(options\.some\(option\s*=>\s*option\.value\s*===\s*currentValue\)\)') `
    'Resolution sync must preserve a valid rough tier when switching between Gemini and GPT option labels.'

Assert-True `
    ($Html -match 'GPT_IMAGE_2_ALLOWED_SIZES\.includes\(String\(size\s*\|\|\s*''''\)\.trim\(\)\)') `
    'gpt-image-2 size validator must allow only documented backend sizes.'

Assert-True `
    ($Html -match 'return\s*sizeMap\[resolution\]\s*\|\|\s*sizeMap\["1K"\]\s*\|\|\s*"1024x1024";') `
    'gpt-image-2 resolution fallback must map to a documented concrete size.'

Assert-True `
    ($Html -match 'if\s*\(isGptImage2Model\(model\)\)\s*return\s*`\$\{option\.label\}\s*->\s*\$\{normalizeGptImage2Resolution\(option\.value,\s*aspectRatio\)\}`;') `
    'gpt-image-2 option labels must show the concrete backend size.'

Assert-True `
    ($Html -notmatch 'function\s+calculateGptImage2Size\(resolution,\s*aspectRatio\)') `
    'gpt-image-2 must not use arbitrary dynamic size calculation.'

$logicMatch = [regex]::Match($Html, '(?s)const\s+DEFAULT_IMAGE_MODEL[\s\S]*?\n\s*function\s+cancelGeneration')
Assert-True $logicMatch.Success 'Could not extract image resolution logic for runtime tests.'

$logic = $logicMatch.Value -replace '\n\s*function\s+cancelGeneration$', ''
$nodeTest = @"
$logic

function assertEqual(actual, expected, name) {
    if (actual !== expected) {
        throw new Error(name + ': expected ' + expected + ', got ' + actual);
    }
}

assertEqual(normalizeGptImage2Resolution('1K', '1:1'), '1024x1024', '1K square maps to documented default size');
assertEqual(normalizeGptImage2Resolution('1K', '3:4'), '1024x1536', '1K portrait maps to documented portrait size');
assertEqual(normalizeGptImage2Resolution('1K', '16:9'), '1920x1080', '1K widescreen maps to documented 16:9 size');
assertEqual(normalizeGptImage2Resolution('2K', '16:9'), '2048x1152', '2K 16:9 maps to popular landscape size');
assertEqual(normalizeGptImage2Resolution('4K', '9:16'), '2160x3840', '4K 9:16 maps to popular portrait size');
assertEqual(normalizeGptImage2Resolution('4K', '1:1'), '2048x2048', '4K square falls back to the largest documented square size');
assertEqual(normalizeGptImage2Resolution('1536x1024', '1:1'), '1536x1024', 'Documented concrete sizes are preserved');
assertEqual(getAllowedImageModelKind('gemini-2.5-flash-image'), null, 'Gemini 2.5 Flash Image is removed');
assertEqual(getAllowedImageModelKind('gemini-3-pro-image-preview'), 'gemini3pro', 'Gemini 3 Pro image model is allowed');
assertEqual(getAllowedImageModelKind('gemini-3.1-fast-image-preview'), 'gemini31fast', 'Gemini 3.1 Fast image model is allowed');
assertEqual(getAllowedImageModelKind('gemini-3.1-flash-image-preview'), 'gemini31fast', 'Gemini 3.1 Flash image model is treated as fast');
assertEqual(getAllowedImageModelKind('gpt-image-2'), 'gptimage2', 'GPT Image 2 is allowed');
assertEqual(getAllowedImageModelKind('gpt-image-2-pro'), 'gptimage2pro', 'GPT Image 2 Pro is allowed as a separate model');
assertEqual(getAllowedImageModelKind('gemini-3.1-flash-image-preview-2k'), null, 'Resolution-suffixed Gemini image models are hidden');
assertEqual(resolveImageModelForRequest('openai', 'gpt-image-2', '2K'), 'gpt-image-2', 'GPT Image 2 request model stays exact and never falls through to Gemini');
assertEqual(resolveImageModelForRequest('openai', 'gpt-image-2-pro', '4K'), 'gpt-image-2-pro', 'GPT Image 2 Pro request model stays exact');
assertEqual(buildOpenAIImagePayload('gpt-image-2-pro', 'prompt', '16:9', '4K').size, '3840x2160', 'GPT Image 2 Pro landscape 4K uses its native backend size');
assertEqual(buildOpenAIImagePayload('gpt-image-2-pro', 'prompt', '9:16', '4K').size, '2160x3840', 'GPT Image 2 Pro portrait 4K uses its native backend size');
assertEqual(resolveImageModelForRequest('openai', 'gemini-2.5-flash-image', '2K'), 'gemini-3-pro-image-preview', 'Removed Gemini 2.5 selections fall back to Gemini 3 Image Pro');
assertEqual(
    extractImageFromGeminiResponse({ candidates: [{ content: { parts: [{ text: '![image](https://cdn.example.com/gemini.png)' }] } }] }),
    'https://cdn.example.com/gemini.png',
    'Gemini extractor reads image URLs returned inside part text'
);
assertEqual(
    extractImageFromGeminiResponse({ candidates: [{ content: { parts: [{ fileData: { fileUri: 'https://cdn.example.com/file-data.png' } }] } }] }),
    'https://cdn.example.com/file-data.png',
    'Gemini extractor reads fileData image URLs'
);
assertEqual(
    extractImageFromGeminiResponse({ choices: [{ message: { content: 'result https://cdn.example.com/openai-style.png' } }] }),
    'https://cdn.example.com/openai-style.png',
    'Gemini proxy extractor also accepts OpenAI-style message content'
);
assertEqual(
    extractImageFromProxyResponse({ response: { images: [{ url: 'https://cdn.example.com/nested.png' }] } }),
    'https://cdn.example.com/nested.png',
    'Proxy extractor reads nested image collections'
);
"@

$nodeTest | node
Assert-True ($LASTEXITCODE -eq 0) 'gpt-image-2 runtime size mapping checks failed.'

$quotaLogicMatch = [regex]::Match($Html, '(?s)function\s+getMagicTokenUsageData[\s\S]*?\n\s*async\s+function\s+fetchTokenQuota')
Assert-True $quotaLogicMatch.Success 'Could not extract token quota display logic for runtime tests.'

$quotaLogic = "const MAGIC_QUOTA_PER_UNIT = 500000;`n" + ($quotaLogicMatch.Value -replace '\n\s*async\s+function\s+fetchTokenQuota$', '')
$quotaNodeTest = @"
$quotaLogic

function assertEqual(actual, expected, name) {
    if (actual !== expected) {
        throw new Error(name + ': expected ' + expected + ', got ' + actual);
    }
}

assertEqual(formatMagicQuotaValue(25000000), '50.00', 'Magic raw quota is converted to display amount');
assertEqual(formatMagicQuotaDisplay({ total_available: 25000000, total_used: 75000, total_granted: 25075000 }), '50.00 / 50.15', 'Magic quota display matches site amount format');
"@

$quotaNodeTest | node
Assert-True ($LASTEXITCODE -eq 0) 'Magic token quota display checks failed.'

Assert-True `
    ($Html -match 'if\s*\(isGptImage2Model\(requestModel\)\)\s*\{\s*payload\.size\s*=\s*normalizeGptImage2Resolution\(resolution,\s*aspectRatio\);[\s\S]*?\}\s*else\s*\{\s*payload\.aspect_ratio\s*=\s*aspectRatio;') `
    'gpt-image-2 must send OpenAI size while non-GPT OpenAI proxy models keep aspect_ratio.'

Assert-True `
    ($Html -match 'const\s+payload\s*=\s*buildOpenAIImagePayload\(requestModel,\s*promptWithAspect,\s*aspectRatio,\s*resolution\);') `
    'OpenAI image requests must use the shared payload builder.'

Assert-True `
    ($Html -match 'imageConfig:\s*\{\s*aspectRatio:\s*aspectRatio,\s*imageSize:\s*resolution\s*\}') `
    'Gemini native image payload must keep using resolution as imageSize.'

Assert-True `
    ($Html -match 'if\s*\(isGeminiImageModel\(selectedModel\)\)\s*\{\s*return\s*normalizeGeminiModelNameForPath\(selectedModel\);') `
    'Gemini proxy requests must keep the selected model instead of mapping resolution into model names.'

Assert-True `
    ($Html -match 'fetch\(buildGeminiGenerateContentUrl\(apiBaseUrl,\s*requestModel\),\s*\{[\s\S]*?''Authorization'':\s*`Bearer \$\{apiKey\}`') `
    'Gemini proxy requests must call generateContent with Bearer authorization.'

Write-Host 'Resolution contract tests passed.'
