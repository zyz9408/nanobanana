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

Assert-Sequence `
    -Actual (Get-OptionValues 'GPT_IMAGE_2_RESOLUTION_OPTIONS') `
    -Expected @('auto', '1K', '2K', '4K') `
    -Name 'gpt-image-2 resolution options'

Assert-True `
    ($Html -match 'function\s+isValidGptImage2Size\(size\)') `
    'gpt-image-2 must validate custom/restored size values.'

Assert-True `
    ($Html -match 'function\s+calculateGptImage2Size\(resolution,\s*aspectRatio\)') `
    'gpt-image-2 must calculate concrete size from resolution tier and aspect ratio.'

Assert-True `
    ($Html -match 'GPT_IMAGE_2_RESOLUTION_TARGET_LONG_EDGE') `
    'gpt-image-2 must keep resolution tiers separate from concrete generated sizes.'

Assert-True `
    ($Html -match "if\s*\(isGptImage2Model\(model\)\)\s*return\s*'1K';") `
    'gpt-image-2 default resolution tier must be 1K.'

Assert-True `
    ($Html -match 'const\s+previousOptionSet\s*=\s*resolutionInput\.dataset\.optionSet;') `
    'Resolution sync must remember the previous model option set.'

Assert-True `
    ($Html -match 'previousOptionSet\s*===\s*optionSet\s*&&\s*options\.some\(option\s*=>\s*option\.value\s*===\s*currentValue\)') `
    'Resolution sync must only preserve the current value within the same model option set.'

Assert-True `
    ($Html -match "if\s*\(size\s*===\s*'auto'\)\s*return\s*true;") `
    'gpt-image-2 must allow auto size.'

Assert-True `
    ($Html -match 'longEdge\s*<=\s*3840') `
    'gpt-image-2 size validator must enforce max edge.'

Assert-True `
    ($Html -match 'width\s*%\s*16\s*===\s*0[\s\S]*height\s*%\s*16\s*===\s*0') `
    'gpt-image-2 size validator must enforce 16px multiples.'

Assert-True `
    ($Html -match 'longEdge\s*/\s*shortEdge\s*<=\s*3') `
    'gpt-image-2 size validator must enforce 3:1 max ratio.'

Assert-True `
    ($Html -match 'Math\.min\(3,\s*Math\.max\(1\s*/\s*3,\s*ratio\)\)') `
    'gpt-image-2 aspect ratio mapping must clamp ratios to the API range.'

Assert-True `
    ($Html -match 'pixels\s*>=\s*655360[\s\S]*pixels\s*<=\s*8294400') `
    'gpt-image-2 size validator must enforce pixel budget.'

$logicMatch = [regex]::Match($Html, '(?s)const\s+GEMINI_RESOLUTION_OPTIONS[\s\S]*?\n\s*function\s+buildProxyAspectRatioPrompt')
Assert-True $logicMatch.Success 'Could not extract image resolution logic for runtime tests.'

$logic = $logicMatch.Value -replace '\n\s*function\s+buildProxyAspectRatioPrompt$', ''
$nodeTest = @"
$logic

function assertEqual(actual, expected, name) {
    if (actual !== expected) {
        throw new Error(name + ': expected ' + expected + ', got ' + actual);
    }
}

assertEqual(normalizeGptImage2Resolution('1K', '9:16'), '720x1280', '1K 9:16 avoids minimum pixel error');
assertEqual(normalizeGptImage2Resolution('2K', '16:9'), '2048x1152', '2K 16:9 maps to popular landscape size');
assertEqual(normalizeGptImage2Resolution('4K', '9:16'), '2160x3840', '4K 9:16 maps to popular portrait size');
assertEqual(normalizeGptImage2Resolution('4K', '1:1'), '2880x2880', '4K square honors max pixel budget');
assertEqual(normalizeGptImage2Resolution('1K', '8:1'), '1440x480', '8:1 clamps to 3:1 API limit');
"@

$nodeTest | node
Assert-True ($LASTEXITCODE -eq 0) 'gpt-image-2 runtime size mapping checks failed.'

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
    ($Html -match "if\s*\(resolution\s*===\s*'2K'\)\s*\{\s*return\s*'gemini-3\.1-flash-image-preview-2k';") `
    'Gemini 2K proxy model mapping must remain intact.'

Assert-True `
    ($Html -match "if\s*\(resolution\s*===\s*'4K'\)\s*\{\s*return\s*'gemini-3\.1-flash-image-preview-4k';") `
    'Gemini 4K proxy model mapping must remain intact.'

Write-Host 'Resolution contract tests passed.'
