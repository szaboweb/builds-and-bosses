$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dataRoot = Join-Path $root 'data'
$schemaRoot = Join-Path $root 'schemas'
$violations = @()

function Add-Violation([string]$message) { $script:violations += $message }
function Test-Range($value, [double]$minimum, [double]$maximum, [string]$label) {
  if ($null -eq $value -or $value -lt $minimum -or $value -gt $maximum) {
    Add-Violation "$label must be between $minimum and $maximum."
  }
}

Get-ChildItem $dataRoot -Recurse -Filter '*.json' | ForEach-Object {
  $file = $_
  if ($file.BaseName -cnotmatch '^[a-z0-9]+(?:_[a-z0-9]+)*$') {
    Add-Violation "Filename must be lowercase snake_case: $($file.FullName)"
  }
  try { $data = Get-Content $file.FullName -Raw | ConvertFrom-Json }
  catch { Add-Violation "Invalid JSON: $($file.FullName)"; return }

  $schema = [string]$data._schema
  if ([string]::IsNullOrWhiteSpace($schema)) {
    Add-Violation "Missing _schema: $($file.FullName)"
    return
  }
  $schemaFile = switch ($schema) {
    'hero_defaults/v1' { 'hero_defaults.v1.schema.json' }
    'hero_save/v1' { 'hero_save.v1.schema.json' }
    'boss/v1' { 'boss.v1.schema.json' }
    'equipment_database/v1' { 'equipment_database.v1.schema.json' }
    default { $null }
  }
  if ($null -eq $schemaFile -or !(Test-Path (Join-Path $schemaRoot $schemaFile))) {
    Add-Violation "Unknown schema '$schema': $($file.FullName)"
    return
  }

  if ($schema -in @('hero_defaults/v1', 'hero_save/v1')) {
    foreach ($ability in @('STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA')) {
      Test-Range $data.attributes.$ability 1 30 "$($file.Name) attributes.$ability"
    }
  }
  if ($schema -eq 'hero_save/v1' -and [string]::IsNullOrWhiteSpace([string]$data.name)) {
    Add-Violation "Hero save name is required: $($file.FullName)"
  }
  if ($schema -eq 'boss/v1') {
    if ([string]$data.id -notmatch '^boss_[0-9]{3}_[a-z0-9_]+$') {
      Add-Violation "Boss id must match boss_###_name: $($file.FullName)"
    }
    Test-Range $data.stats.max_hp 1 100000 "$($file.Name) stats.max_hp"
    Test-Range $data.stats.armor_class 1 40 "$($file.Name) stats.armor_class"
  }
  if ($schema -eq 'equipment_database/v1') {
    if ($data.sets.Count -ne 4) {
      Add-Violation "Equipment database must define exactly four class-role sets: $($file.FullName)"
    }
    foreach ($set in $data.sets) {
      if ([string]$set.role -notin @('frontline', 'ranged', 'divineCaster', 'arcaneCaster')) {
        Add-Violation "Unknown equipment role '$($set.role)': $($file.FullName)"
      }
    }
  }
}

if ($violations.Count -gt 0) {
  $violations | ForEach-Object { Write-Error $_ }
  exit 1
}
Write-Host 'Data schema and naming validation passed.'