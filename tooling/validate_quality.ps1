param(
    [switch]$Staged,
    [string]$BaseRef = 'HEAD',
    [string]$Dart
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Dart) {
    $configured = git -C $root config --get buildsAndBosses.dartPath
    if ($LASTEXITCODE -notin @(0, 1)) { throw 'Cannot read Dart toolchain configuration' }
    $Dart = if ($configured) { $configured } else { 'dart' }
}
$tool = Join-Path $root 'tooling\code_quality'
$packages = Join-Path $tool '.dart_tool\package_config.json'
if (-not (Test-Path -LiteralPath $packages)) {
    throw 'Restore quality dependencies first: cd tooling\code_quality; dart pub get'
}
$snapshot = $null
$reference = $null
$original = Get-Location
try {
    Set-Location $root
    $source = $root
    if ($Staged) {
        $snapshot = Join-Path ([IO.Path]::GetTempPath()) ('bb-quality-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $snapshot | Out-Null
        $prefix = $snapshot.Replace('\', '/') + '/'
        git checkout-index --all "--prefix=$prefix"
        if ($LASTEXITCODE -ne 0) { throw 'Cannot create staged snapshot' }
        $source = $snapshot
        foreach ($package in @('app', 'tooling\code_quality')) {
            foreach ($manifest in @('pubspec.yaml', 'pubspec.lock')) {
                $currentManifest = Join-Path (Join-Path $root $package) $manifest
                $stagedManifest = Join-Path (Join-Path $source $package) $manifest
                if ([IO.File]::ReadAllText($currentManifest).Replace("`r`n", "`n") -ne
                    [IO.File]::ReadAllText($stagedManifest).Replace("`r`n", "`n")) {
                    throw "Restore dependencies and stage matching manifest/lock files: $package"
                }
            }
            $config = Join-Path (Join-Path $root $package) '.dart_tool\package_config.json'
            if (-not (Test-Path -LiteralPath $config)) { throw "Restore dependencies first: $package" }
            $target = Join-Path (Join-Path $source $package) '.dart_tool'
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Copy-Item -LiteralPath $config -Destination (Join-Path $target 'package_config.json')
        }
        & (Join-Path $source 'tooling\validate_architecture.ps1') -SourceRoot $source
        if (-not $?) { throw 'Staged architecture validation failed' }
        & (Join-Path $source 'tooling\validate_data.ps1') -SourceRoot $source
        if (-not $?) { throw 'Staged data validation failed' }
    }
    $checker = Join-Path $source 'tooling\code_quality\bin\check.dart'
    if (-not (Test-Path -LiteralPath $checker)) {
        throw 'Quality checker missing from snapshot; stage its files first.'
    }
    $checkerArgs = @("--packages=$packages", $checker, 'check', '--root', $source)
    if ($BaseRef) {
        $paths = @(git ls-tree -r --name-only $BaseRef)
        if ($LASTEXITCODE -ne 0) { throw "Invalid base revision: $BaseRef" }
        if ($paths -contains 'tooling/code_quality/baseline.json') {
            $reference = Join-Path ([IO.Path]::GetTempPath()) ('bb-quality-base-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $reference | Out-Null
            $archive = Join-Path $reference 'source.tar'
            git archive --format=tar "-o$archive" $BaseRef app/lib tooling/code_quality/lib tooling/code_quality/bin
            if ($LASTEXITCODE -ne 0) { throw 'Cannot export merge-base sources' }
            tar -xf $archive -C $reference
            if ($LASTEXITCODE -ne 0) { throw 'Cannot read merge-base sources' }
            $checkerArgs += @('--reference-root', $reference)
        }
    }
    & $Dart @checkerArgs
    if ($LASTEXITCODE -ne 0) { throw 'Quality ratchet failed' }

    $changed = if ($Staged) {
        git diff --cached --name-only --diff-filter=ACMR
    } elseif ($BaseRef) {
        @(git diff $BaseRef --name-only --diff-filter=ACMR) +
            @(git ls-files --others --exclude-standard)
    } else {
        @(git diff HEAD --name-only --diff-filter=ACMR) +
            @(git ls-files --others --exclude-standard)
    }
    if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate changed sources' }
    $dartFiles = @($changed | Where-Object {
        $_ -match '^(app/(lib|test)|tooling/code_quality)/.*\.dart$'
    } | ForEach-Object { Join-Path $source $_ } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique)
    if ($dartFiles.Count -gt 0) {
        & $Dart format --output=none --set-exit-if-changed @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Changed Dart files need formatting' }
    }

    if ($BaseRef) {
        if ($paths -contains 'tooling/code_quality/baseline.json') {
            $oldBaseline = git show "${BaseRef}:tooling/code_quality/baseline.json"
            if ($LASTEXITCODE -ne 0) { throw 'Cannot read base baseline' }
            $baseline = Join-Path $source 'tooling\code_quality\baseline.json'
            $current = Get-Content -LiteralPath $baseline -Raw | ConvertFrom-Json
            $previous = ($oldBaseline -join "`n") | ConvertFrom-Json
            foreach ($file in $current.files.PSObject.Properties) {
                $before = $previous.files.PSObject.Properties[$file.Name]
                if ($null -eq $before) { throw "New baseline exemption requires review: $($file.Name)" }
                if ($file.Value.lines -gt $before.Value.lines) {
                    throw "Baseline increase forbidden: $($file.Name)"
                }
                foreach ($symbol in $file.Value.symbols.PSObject.Properties) {
                    $oldSymbol = $before.Value.symbols.PSObject.Properties[$symbol.Name]
                    if ($null -eq $oldSymbol) { throw "New baseline symbol exemption: $($symbol.Name)" }
                    foreach ($metric in $symbol.Value.PSObject.Properties) {
                        if ($metric.Value -gt $oldSymbol.Value.($metric.Name)) {
                            throw "Baseline metric increase: $($file.Name):$($symbol.Name)"
                        }
                    }
                }
            }
        } else {
            Write-Host 'Initial baseline rollout: no baseline in base revision.'
        }
    }
} finally {
    Set-Location $original
    if ($snapshot -and (Test-Path -LiteralPath $snapshot)) {
        Remove-Item -LiteralPath $snapshot -Recurse -Force
    }
    if ($reference -and (Test-Path -LiteralPath $reference)) {
        Remove-Item -LiteralPath $reference -Recurse -Force
    }
}
