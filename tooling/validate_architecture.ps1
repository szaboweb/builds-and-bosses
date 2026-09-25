$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'app'
$violations = @()

function Add-Violation([string]$message) {
  $script:violations += $message
}

Get-ChildItem (Join-Path $project 'lib/core') -Recurse -Filter '*.dart' | ForEach-Object {
  $content = Get-Content $_.FullName -Raw
  if ($content -match "package:flutter/(?!foundation\.dart)|package:flame/(?!extensions\.dart)|dart:ui") {
    Add-Violation "core must remain headless: $($_.FullName)"
  }
}

Get-ChildItem (Join-Path $project 'lib/game') -Recurse -Filter '*.dart' | ForEach-Object {
  $content = Get-Content $_.FullName -Raw
  if ($content -match 'Random\s*\(') {
    Add-Violation "game must use core Dice/services instead of Random: $($_.FullName)"
  }
  if ($content -match 'Dice\.(d20|rollMultiple)\s*\(') {
    Add-Violation "game must delegate dice rolls to a core combat service: $($_.FullName)"
  }
}

Get-ChildItem (Join-Path $project 'lib/ui') -Recurse -Filter '*.dart' | ForEach-Object {
  $content = Get-Content $_.FullName -Raw
  if ($content -match 'combat_engine\.dart|dnd/dice\.dart|Random\s*\(') {
    Add-Violation "ui must not implement combat or RNG: $($_.FullName)"
  }
}

Get-ChildItem (Join-Path $project 'lib') -Recurse -Filter '*.dart' | ForEach-Object {
  $content = Get-Content $_.FullName -Raw
  if ($content -match '(?m)(?<!debug)\bprint\s*\(') {
    Add-Violation "production code must use structured logging instead of print: $($_.FullName)"
  }
}

if ($violations.Count -gt 0) {
  $violations | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'Architecture validation passed.'