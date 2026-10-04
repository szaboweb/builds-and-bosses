<#
.SYNOPSIS
  Exports per-animation sprite sheets from Aseprite source files for character classes.
.DESCRIPTION
  For each assets/characters/<class_id>/source.aseprite file, exports every animation
  tag (idle, run, jump, fall, attack, block, cast, hit, dodge, death, ...) as its own
  horizontal sprite sheet PNG + JSON metadata, matching docs/MOVEMENT_AND_TUI_GUIDE.md.
.PARAMETER AsepritePath
  Path to Aseprite.exe. Defaults to the standard Windows install location.
.PARAMETER ClassId
  Optional: export a single character class only (e.g. "fighter"). Defaults to all.
#>
param(
  [string]$AsepritePath = 'C:\Program Files\Aseprite\Aseprite.exe',
  [string]$ClassId
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'invoke_checked_process.ps1')
$root = Split-Path -Parent $PSScriptRoot
$charactersRoot = Join-Path $root 'assets\characters'

if (!(Test-Path $AsepritePath)) {
  Write-Error "Aseprite executable not found at '$AsepritePath'. Pass -AsepritePath to override."
  exit 1
}

$classDirs = Get-ChildItem $charactersRoot -Directory -ErrorAction SilentlyContinue
if ($ClassId) {
  $classDirs = $classDirs | Where-Object { $_.Name -eq $ClassId }
}

if (-not $classDirs) {
  Write-Error "No character folders found under $charactersRoot"
  exit 1
}

$exports = 0

foreach ($classDir in $classDirs) {
  $source = Join-Path $classDir.FullName 'source.aseprite'
  if (!(Test-Path $source)) {
    Write-Warning "Skipping $($classDir.Name): no source.aseprite found."
    continue
  }

  Write-Host "== $($classDir.Name) =="
  $tagOutput = Invoke-CheckedProcess -Executable $AsepritePath `
    -Arguments @('-b', '--list-tags', ('"' + $source + '"'))
  $tags = $tagOutput -split '\r?\n' | Where-Object { $_ -and $_.Trim() -ne '' }

  if (-not $tags) {
    Write-Warning "No animation tags found in $source"
    continue
  }

  foreach ($tag in $tags) {
    $tag = $tag.Trim()
    if ($tag -notmatch '^[A-Za-z0-9_-]+$') { throw "Unsafe animation tag: $tag" }
    $sheetPath = Join-Path $classDir.FullName "$tag.png"
    $dataPath = Join-Path $classDir.FullName "$tag.json"
    Write-Host "  exporting $tag -> $($classDir.Name)\$tag.png"
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('bb-export-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $temporary | Out-Null
    $freshSheet = Join-Path $temporary "$tag.png"
    $freshData = Join-Path $temporary "$tag.json"
    try {
    Invoke-CheckedProcess -Executable $AsepritePath -Arguments @(
      '-b', '--tag', ('"' + $tag + '"'), ('"' + $source + '"'),
      '--sheet-type', 'horizontal', '--sheet', ('"' + $freshSheet + '"'),
      '--data', ('"' + $freshData + '"')
    )
    foreach ($output in @($freshSheet, $freshData)) {
      if (-not (Test-Path -LiteralPath $output) -or
          (Get-Item -LiteralPath $output).Length -eq 0) {
        throw "Export output missing or empty: $output"
      }
    }
    Get-Content -LiteralPath $freshData -Raw | ConvertFrom-Json | Out-Null
    Move-Item -LiteralPath $freshSheet -Destination $sheetPath -Force
    Move-Item -LiteralPath $freshData -Destination $dataPath -Force
    $exports++
    } finally {
      Remove-Item -LiteralPath $temporary -Recurse -Force
    }
  }
}

if ($exports -eq 0) { throw 'No sprites were exported.' }
Write-Host "Sprite export complete: $exports sheets."
