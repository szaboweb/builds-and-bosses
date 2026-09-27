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

$failures = @()

foreach ($classDir in $classDirs) {
  $source = Join-Path $classDir.FullName 'source.aseprite'
  if (!(Test-Path $source)) {
    Write-Warning "Skipping $($classDir.Name): no source.aseprite found."
    continue
  }

  Write-Host "== $($classDir.Name) =="
  $tags = & $AsepritePath -b --list-tags $source | Where-Object { $_ -and $_.Trim() -ne '' }

  if (-not $tags) {
    Write-Warning "No animation tags found in $source"
    continue
  }

  foreach ($tag in $tags) {
    $tag = $tag.Trim()
    $sheetPath = Join-Path $classDir.FullName "$tag.png"
    $dataPath = Join-Path $classDir.FullName "$tag.json"
    Write-Host "  exporting $tag -> $($classDir.Name)\$tag.png"
    & $AsepritePath -b --tag $tag $source --sheet-type horizontal --sheet $sheetPath --data $dataPath
    if ($LASTEXITCODE -ne 0) {
      $failures += "$($classDir.Name)/$tag"
    }
  }
}

if ($failures.Count -gt 0) {
  Write-Error "Export failed for: $($failures -join ', ')"
  exit 1
}
Write-Host 'Sprite export complete.'
