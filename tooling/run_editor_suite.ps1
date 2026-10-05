param(
    [switch]$IncludeGame,
    [switch]$WithQuality,
    [switch]$Format
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $root 'app'

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

if ($Format) {
    Write-Host "==> Checking and formatting changed Dart files..." -ForegroundColor Cyan
    Set-Location $root
    $changed = @(git diff HEAD --name-only --diff-filter=ACMR) + @(git ls-files --others --exclude-standard)
    $dartFiles = @($changed | Where-Object {
        $_ -match '^(app/(lib|test)|tooling/code_quality)/.*\.dart$'
    } | ForEach-Object { Join-Path $root $_ } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique)

    if ($dartFiles.Count -gt 0) {
        dart format @dartFiles
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Dart format failed."
            exit 1
        }
    }
}

$testFiles = @(
    'test/arena_layout_blueprint_test.dart',
    'test/editor_geometry_test.dart',
    'test/motion_vector_gizmo_test.dart',
    'test/unique_id_test.dart',
    'test/level_editor_ui_test.dart',
    'test/level_editor_integration_test.dart'
)

if ($IncludeGame) {
    $testFiles += @(
        'test/moving_platform_test.dart',
        'test/tactical_game_test.dart'
    )
}

Write-Host "==> Running Level Editor test suite ($($testFiles.Count) files) in compact mode..." -ForegroundColor Cyan

Push-Location $appDir
try {
    flutter test @testFiles --reporter=compact
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Level Editor test suite failed."
        exit 1
    }
} finally {
    Pop-Location
}

if ($WithQuality) {
    Write-Host "`n==> Running code quality gate (validate_quality.ps1)..." -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'validate_quality.ps1')
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Quality validation gate failed."
        exit 1
    }
}

$stopwatch.Stop()
$elapsedSec = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
Write-Host "`n[SUCCESS] Level Editor suite passed! (${elapsedSec}s elapsed)" -ForegroundColor Green
