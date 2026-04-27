# publish.ps1 — Auto-publish a ticker analysis to the live dashboard
#
# Save to: C:\Users\Oliver\trading-dashboard-deploy\scripts\publish.ps1
#
# Usage (called by Claude Code at the end of the deep-dive prompt):
#   .\publish.ps1 -Ticker NVDA -JsonObjectFile "C:\path\to\NVDA_2026-04-26.js"
#
# What it does:
#   1. Reads the JS object file (a single { ... } block) Claude Code wrote
#   2. Locates the EZPZ_INDIVIDUAL fence in index.html
#   3. Inserts the new object at the top of the array (newest first)
#   4. Removes any prior entry for the same ticker (so re-analyses replace, not duplicate)
#   5. Optionally also writes/updates the watchlist if -Watchlist flag is set
#   6. git add → commit → push
#   7. Reports the live URL

param(
    [Parameter(Mandatory=$true)]
    [string]$Ticker,

    [Parameter(Mandatory=$true)]
    [string]$JsonObjectFile,

    [string]$RepoPath = "$env:USERPROFILE\trading-dashboard-deploy",

    [switch]$Watchlist,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$Ticker = $Ticker.ToUpper()

Write-Host "`n=== EZPZ Publish: $Ticker ===" -ForegroundColor Cyan

# 1. Sanity checks
$IndexPath = Join-Path $RepoPath "index.html"
if (-not (Test-Path $IndexPath)) {
    Write-Host "ERROR: index.html not found at $IndexPath" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $JsonObjectFile)) {
    Write-Host "ERROR: Analysis object file not found: $JsonObjectFile" -ForegroundColor Red
    exit 1
}

$newObject = Get-Content $JsonObjectFile -Raw -Encoding UTF8
$newObject = $newObject.Trim()
# Strip outer brackets/parens if Claude wrapped them
if ($newObject.StartsWith('[')) { $newObject = $newObject.Substring(1) }
if ($newObject.EndsWith(']'))   { $newObject = $newObject.Substring(0, $newObject.Length - 1) }
$newObject = $newObject.Trim().TrimEnd(',').Trim()
if (-not $newObject.StartsWith('{')) {
    Write-Host "ERROR: Object file does not start with '{'. Got: $($newObject.Substring(0, [Math]::Min(40,$newObject.Length)))" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Loaded analysis object ($($newObject.Length) chars)" -ForegroundColor Green

# 2. Read index.html
$html = Get-Content $IndexPath -Raw -Encoding UTF8

# Choose target fence
if ($Watchlist) {
    $startFence = "/* EZPZ_WATCHLIST_START */"
    $endFence   = "/* EZPZ_WATCHLIST_END */"
    $constName  = "EZPZ_WATCHLIST"
} else {
    $startFence = "/* EZPZ_INDIVIDUAL_START */"
    $endFence   = "/* EZPZ_INDIVIDUAL_END */"
    $constName  = "EZPZ_INDIVIDUAL"
}

$startIdx = $html.IndexOf($startFence)
$endIdx   = $html.IndexOf($endFence)
if ($startIdx -lt 0 -or $endIdx -lt 0) {
    Write-Host "ERROR: Could not locate fences in index.html — '$startFence' or '$endFence' missing" -ForegroundColor Red
    exit 1
}

$beforeBlock = $html.Substring(0, $startIdx + $startFence.Length)
$afterBlock  = $html.Substring($endIdx)
$arrayBlock  = $html.Substring($startIdx + $startFence.Length, $endIdx - $startIdx - $startFence.Length)

# 3. Find array opening "[" and closing "]"
$arrOpen  = $arrayBlock.IndexOf('[')
$arrClose = $arrayBlock.LastIndexOf(']')
if ($arrOpen -lt 0 -or $arrClose -lt 0 -or $arrClose -le $arrOpen) {
    Write-Host "ERROR: Could not find array brackets between fences" -ForegroundColor Red
    exit 1
}

$preArray   = $arrayBlock.Substring(0, $arrOpen + 1)             # up to and including '['
$inArray    = $arrayBlock.Substring($arrOpen + 1, $arrClose - $arrOpen - 1)  # between brackets
$postArray  = $arrayBlock.Substring($arrClose)                   # ']' onwards

# 4. Remove any existing entry for this ticker
# Match: { ... ticker: "TICKER" ... }, with proper brace balance
$existingTickerPattern = '(?ms)\{[^{}]*?ticker\s*:\s*"' + [regex]::Escape($Ticker) + '"[^{}]*?(?:\{[^{}]*\}[^{}]*?)*\},?'
$beforeCount = [regex]::Matches($inArray, $existingTickerPattern).Count
if ($beforeCount -gt 0) {
    $inArray = [regex]::Replace($inArray, $existingTickerPattern, '')
    Write-Host "[OK] Removed $beforeCount prior entry/entries for $Ticker" -ForegroundColor Yellow
}

# 5. Build new array contents — newest first
$inArray = $inArray.Trim()
if ($inArray.StartsWith(',')) { $inArray = $inArray.Substring(1).Trim() }
if ($inArray.Length -gt 0) {
    $newInner = "`n  " + $newObject + ",`n  " + $inArray
} else {
    $newInner = "`n  " + $newObject + "`n"
}

# 6. Reassemble
$newArrayBlock = $preArray + $newInner + "`n" + $postArray
$newHtml = $beforeBlock + $newArrayBlock + $afterBlock

if ($DryRun) {
    Write-Host "`n[DRY RUN] Would write $($newHtml.Length) chars to index.html" -ForegroundColor Yellow
    $previewPath = Join-Path $env:TEMP "ezpz_publish_preview.html"
    Set-Content $previewPath $newHtml -Encoding UTF8
    Write-Host "[DRY RUN] Preview written to: $previewPath" -ForegroundColor Yellow
    exit 0
}

# 7. Write
Set-Content $IndexPath $newHtml -Encoding UTF8
Write-Host "[OK] Spliced $Ticker into $constName" -ForegroundColor Green

# 8. git add → commit → push
Push-Location $RepoPath
try {
    git add "index.html" 2>&1 | Out-Null
    $hasChanges = (git status --porcelain) -ne $null
    if (-not $hasChanges) {
        Write-Host "[INFO] No git changes detected (file unchanged)." -ForegroundColor Yellow
        exit 0
    }
    $msg = "ezpz: $Ticker $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git commit -m $msg 2>&1 | Out-Null
    Write-Host "[OK] Committed: $msg" -ForegroundColor Green
    git push 2>&1 | Out-Null
    Write-Host "[OK] Pushed to GitHub" -ForegroundColor Green
} finally {
    Pop-Location
}

# 9. Report live URL
$liveUrl = "https://olivertruelove123.github.io/trading-dashboard/"
Write-Host "`nLive in ~30 seconds:" -ForegroundColor Cyan
Write-Host "  $liveUrl#tab-ezpz" -ForegroundColor White
Write-Host "  (Click '$Ticker' in EZPZ Deep tab to see full analysis)" -ForegroundColor Gray
Write-Host ""
