param(
    [int]$MinLines = 0,
    [switch]$YellowAndRed,
    [switch]$ChangedOnly,
    [int]$Top = 0,
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$targetDirectories = @(
    (Join-Path $root 'app\lib'),
    (Join-Path $root 'tooling\code_quality\lib'),
    (Join-Path $root 'tooling\code_quality\bin')
)

$allDartFiles = @()
foreach ($dir in $targetDirectories) {
    if (Test-Path -LiteralPath $dir) {
        $files = Get-ChildItem -LiteralPath $dir -Recurse -Filter '*.dart'
        $allDartFiles += $files
    }
}

if ($ChangedOnly) {
    Set-Location $root
    $changed = @(git diff HEAD --name-only --diff-filter=ACMR) + @(git ls-files --others --exclude-standard)
    $changedPaths = @($changed | ForEach-Object { (Join-Path $root $_).Replace('/', '\') })
    $allDartFiles = @($allDartFiles | Where-Object { $changedPaths -contains $_.FullName })
    if ($allDartFiles.Count -eq 0) {
        Write-Host "No changed Dart files found in tracked scope." -ForegroundColor Yellow
        exit 0
    }
}

$results = @()
$sha256 = [System.Security.Cryptography.SHA256]::Create()

foreach ($file in $allDartFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $lines = if ([string]::IsNullOrEmpty($content)) { 0 } else {
        $count = ([regex]::Matches($content, '\n')).Count
        if ($content.EndsWith("`n")) { $count } else { $count + 1 }
    }

    $zone = if ($lines -lt 350) {
        '[GREEN]'
    } elseif ($lines -lt 550) {
        '[YELLOW]'
    } elseif ($lines -le 650) {
        '[RED]'
    } else {
        '[EXCEEDED]'
    }

    $capToYellow = [Math]::Max(0, 350 - $lines)
    $capToRed = [Math]::Max(0, 550 - $lines)
    $capToMax = [Math]::Max(0, 650 - $lines)

    $relPath = $file.FullName.Substring($root.Length + 1).Replace('\', '/')

    $hashStr = ''
    if ($Detailed) {
        $normalized = $content.Replace("`r`n", "`n")
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
        $hashBytes = $sha256.ComputeHash($bytes)
        $hashStr = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
    }

    $item = [PSCustomObject]@{
        Zone        = $zone
        Lines       = $lines
        'Cap->350'  = $capToYellow
        'Cap->550'  = $capToRed
        'Cap->650'  = $capToMax
        File        = $relPath
    }
    if ($Detailed) {
        $item | Add-Member -NotePropertyName 'SourceHash' -NotePropertyValue $hashStr
    }

    $results += $item
}

$effectiveMin = if ($YellowAndRed) { 350 } else { $MinLines }
$filtered = @($results | Where-Object { $_.Lines -ge $effectiveMin })
$sorted = @($filtered | Sort-Object -Property Lines -Descending)

if ($Top -gt 0) {
    $sorted = @($sorted | Select-Object -First $Top)
}

Write-Host "`n=== FILE CAPACITY & ZONE REPORT ===" -ForegroundColor Cyan
if ($sorted.Count -gt 0) {
    $sorted | Format-Table -AutoSize | Out-Host
} else {
    Write-Host "No files match the criteria (MinLines: $effectiveMin)." -ForegroundColor Yellow
}

$greenCount = @($results | Where-Object { $_.Lines -lt 350 }).Count
$yellowCount = @($results | Where-Object { $_.Lines -ge 350 -and $_.Lines -lt 550 }).Count
$redCount = @($results | Where-Object { $_.Lines -ge 550 -and $_.Lines -le 650 }).Count
$overLimitCount = @($results | Where-Object { $_.Lines -gt 650 }).Count

Write-Host "Summary: $($results.Count) files scanned." -ForegroundColor Gray
Write-Host "  [GREEN]   (0 - 349 lines)   : $greenCount files" -ForegroundColor Green
Write-Host "  [YELLOW]  (350 - 549 lines) : $yellowCount files" -ForegroundColor Yellow
Write-Host "  [RED]     (550 - 650 lines) : $redCount files" -ForegroundColor Red
if ($overLimitCount -gt 0) {
    Write-Host "  [EXCEEDED] (> 650 lines)   : $overLimitCount files (VIOLATION!)" -ForegroundColor Magenta
}
Write-Host ""
