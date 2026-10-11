<#
.SYNOPSIS
  Renders a 3D character/boss animation from a .blend file to 2D sprites and bundles with Aseprite.
.DESCRIPTION
  Runs Blender headlessly to orient an orthographic camera, set 3-point studio lighting,
  and render individual transparent frames of an animation action.
  Then executes Aseprite headlessly to produce .aseprite, a horizontal spritesheet PNG, JSON metadata, and GIF.
.PARAMETER BlendFile
  Path to the source .blend file (e.g. 'C:\Users\mrsza\Downloads\hellhound.blend').
.PARAMETER OutDir
  Output directory to save frames and spritesheets (e.g. 'app/assets/images/characters/hellhound').
.PARAMETER Action
  Animation action name to render (e.g. 'Walk'). Defaults to first/active action.
.PARAMETER Name
  Base name for the generated spritesheet and .aseprite file. Defaults to blend file name.
.PARAMETER ResolutionX
  Per-frame width in pixels. Default is 160.
.PARAMETER ResolutionY
  Per-frame height in pixels. Default is 64.
.PARAMETER ElevationDeg
  Camera elevation angle above horizon in degrees. Default is 12.0.
.PARAMETER BlenderPath
  Explicit path to blender.exe. Defaults to standard install locations.
.PARAMETER AsepritePath
  Explicit path to Aseprite.exe. Defaults to standard install locations.
.PARAMETER NoAseprite
  Skip Aseprite spritesheet packaging.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$BlendFile,

  [Parameter(Mandatory = $true)]
  [string]$OutDir,

  [string]$Action = '',
  [string]$Name = '',
  [int]$ResolutionX = 160,
  [int]$ResolutionY = 64,
  [double]$ElevationDeg = 12.0,
  [string]$BlenderPath = '',
  [string]$AsepritePath = '',
  [switch]$NoAseprite
)

$ErrorActionPreference = 'Stop'

# 1. Resolve Blender executable
if (-not $BlenderPath -or -not (Test-Path $BlenderPath)) {
  $blenderCandidates = @(
    "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
    "C:\Program Files\Blender Foundation\Blender\blender.exe"
  )
  foreach ($cand in $blenderCandidates) {
    if (Test-Path $cand) {
      $BlenderPath = $cand
      break
    }
  }
  if (-not $BlenderPath) {
    $found = Get-Command blender.exe -ErrorAction SilentlyContinue
    if ($found) { $BlenderPath = $found.Source }
  }
}

if (-not $BlenderPath -or -not (Test-Path $BlenderPath)) {
  Write-Error "Blender executable not found. Pass -BlenderPath to specify."
  exit 1
}

# 2. Resolve Aseprite executable if bundling
if (-not $NoAseprite) {
  if (-not $AsepritePath -or -not (Test-Path $AsepritePath)) {
    if ($env:ASEPRITE_PATH -and (Test-Path $env:ASEPRITE_PATH)) {
      $AsepritePath = $env:ASEPRITE_PATH
    } else {
      $aseCandidates = @(
        "C:\Program Files\Aseprite\Aseprite.exe",
        "C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe"
      )
      foreach ($cand in $aseCandidates) {
        if (Test-Path $cand) {
          $AsepritePath = $cand
          break
        }
      }
      if (-not $AsepritePath) {
        $foundAse = Get-Command Aseprite.exe -ErrorAction SilentlyContinue
        if ($foundAse) { $AsepritePath = $foundAse.Source }
      }
    }
  }
}

if (-not (Test-Path $BlendFile)) {
  Write-Error "Blend file not found: '$BlendFile'"
  exit 1
}

$scriptPath = Join-Path $PSScriptRoot 'render_blend_to_sprites.py'
if (-not (Test-Path $scriptPath)) {
  Write-Error "Python render script missing at '$scriptPath'"
  exit 1
}

$pyArgs = @(
  '-b', $BlendFile,
  '-P', $scriptPath,
  '--',
  '--out-dir', $OutDir,
  '--res-x', $ResolutionX,
  '--res-y', $ResolutionY,
  '--elev-deg', $ElevationDeg
)

if ($Action) { $pyArgs += @('--action', $Action) }
if ($Name) { $pyArgs += @('--name', $Name) }
if (-not $NoAseprite -and $AsepritePath) {
  $pyArgs += @('--aseprite', '--aseprite-path', $AsepritePath)
}

Write-Host "== Exporting Blend to Sprites =="
Write-Host "Blend:   $BlendFile"
Write-Host "OutDir:  $OutDir"
Write-Host "Blender: $BlenderPath"
if ($AsepritePath) { Write-Host "Aseprite: $AsepritePath" }

& $BlenderPath @pyArgs
if ($LASTEXITCODE -ne 0) {
  Write-Error "Blender export failed with exit code $LASTEXITCODE"
  exit $LASTEXITCODE
}

Write-Host "== Export Complete =="
Get-ChildItem $OutDir | Select-Object Name, Length
