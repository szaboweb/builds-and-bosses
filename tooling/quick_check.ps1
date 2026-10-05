param(
    [string]$TestFile
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

Set-Location $root

Write-Host "==> 1. Checking and formatting changed Dart files..." -ForegroundColor Cyan
$changed = @(git diff HEAD --name-only --diff-filter=ACMR) + @(git ls-files --others --exclude-standard)
$dartFiles = @($changed | Where-Object {
    $_ -match '^(app/(lib|test)|tooling/code_quality)/.*\.dart$'
} | ForEach-Object { Join-Path $root $_ } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique)

if ($dartFiles.Count -gt 0) {
    Write-Host "Formatting $($dartFiles.Count) changed Dart files..."
    dart format @dartFiles
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Dart format failed."
        exit 1
    }
} else {
    Write-Host "No changed Dart files to format."
}

if ($TestFile) {
    Write-Host "==> 2. Running focused test: $TestFile" -ForegroundColor Cyan
    $appDir = Join-Path $root 'app'
    $targetTest = $TestFile
    if ($targetTest.StartsWith('app/')) {
        $targetTest = $targetTest.Substring(4)
    }
    
    Push-Location $appDir
    try {
        flutter test $targetTest --reporter=compact
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Test execution failed for: $TestFile"
            exit 1
        }
    } finally {
        Pop-Location
    }
}

Write-Host "==> 3. Running code quality gate (validate_quality.ps1)..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'validate_quality.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Error "Quality validation gate failed."
    exit 1
}

Write-Host "`n[SUCCESS] Quick check passed! Format, test, and quality gates are green." -ForegroundColor Green
