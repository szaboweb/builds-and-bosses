param(
    [switch]$ExportDefault,
    [string]$InputFile,
    [string]$OutputFile,
    [string]$Directory = 'assets\dungeons'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Test-BlueprintObject {
    param([PSCustomObject]$bp, [string]$sourceName)
    $errors = @()

    if (-not $bp.name) { $errors += "$($sourceName): Missing 'name'." }
    if ($null -eq $bp.version) { $errors += "$($sourceName): Missing 'version'." }

    if ($null -eq $bp.arenaWidth -or $bp.arenaWidth -le 0) {
        $errors += "$($sourceName): 'arenaWidth' must be greater than 0."
    }
    if ($null -eq $bp.arenaHeight -or $bp.arenaHeight -le 0) {
        $errors += "$($sourceName): 'arenaHeight' must be greater than 0."
    }

    if ($null -ne $bp.playerSpawnX -and $null -ne $bp.arenaWidth) {
        if ($bp.playerSpawnX -lt 0 -or $bp.playerSpawnX -gt $bp.arenaWidth) {
            $errors += "$($sourceName): 'playerSpawnX' ($($bp.playerSpawnX)) is out of arena bounds [0, $($bp.arenaWidth)]."
        }
    } else {
        $errors += "$($sourceName): Missing 'playerSpawnX'."
    }

    if ($null -ne $bp.playerSpawnY -and $null -ne $bp.arenaHeight) {
        if ($bp.playerSpawnY -lt 0 -or $bp.playerSpawnY -gt $bp.arenaHeight) {
            $errors += "$($sourceName): 'playerSpawnY' ($($bp.playerSpawnY)) is out of arena bounds [0, $($bp.arenaHeight)]."
        }
    } else {
        $errors += "$($sourceName): Missing 'playerSpawnY'."
    }

    $validTypes = @('staticStone', 'movingStone', 'hazardSpikes')
    if ($bp.platforms) {
        $platformIndex = 0
        foreach ($p in $bp.platforms) {
            if (-not $p.id) { $errors += "$($sourceName): platform[$platformIndex] missing 'id'." }
            if ($p.type -notin $validTypes) {
                $errors += "$($sourceName): platform[$platformIndex] has invalid type '$($p.type)'. Must be one of: $($validTypes -join ', ')."
            }
            if ($null -eq $p.width -or $p.width -le 0) {
                $errors += "$($sourceName): platform[$platformIndex] ($($p.id)) width must be > 0."
            }
            if ($null -eq $p.height -or $p.height -le 0) {
                $errors += "$($sourceName): platform[$platformIndex] ($($p.id)) height must be > 0."
            }
            if ($p.type -eq 'movingStone') {
                if (-not $p.kinematics) {
                    $errors += "$($sourceName): movingStone platform '$($p.id)' missing 'kinematics'."
                } elseif ($null -eq $p.kinematics.travelDistance -or $null -eq $p.kinematics.speed) {
                    $errors += "$($sourceName): kinematics for platform '$($p.id)' requires travelDistance and speed."
                }
            }
            $platformIndex++
        }
    }

    if ($bp.spawns) {
        $spawnIndex = 0
        foreach ($s in $bp.spawns) {
            if (-not $s.id) { $errors += "$($sourceName): spawn[$spawnIndex] missing 'id'." }
            if (-not $s.type) { $errors += "$($sourceName): spawn[$spawnIndex] missing 'type'." }
            $spawnIndex++
        }
    }

    return $errors
}

function New-DefaultArenaBlueprint {
    return [ordered]@{
        name         = 'Trial Grounds'
        version      = 1
        arenaWidth   = 2400.0
        arenaHeight  = 900.0
        playerSpawnX = 180.0
        playerSpawnY = 822.0
        platforms    = @(
            [ordered]@{
                id     = 'plat_ground_main'
                type   = 'staticStone'
                x      = 0.0
                y      = 840.0
                width  = 2400.0
                height = 60.0
            },
            [ordered]@{
                id     = 'plat_pillar_left'
                type   = 'staticStone'
                x      = 320.0
                y      = 720.0
                width  = 180.0
                height = 22.0
            },
            [ordered]@{
                id     = 'plat_pillar_center'
                type   = 'staticStone'
                x      = 720.0
                y      = 640.0
                width  = 220.0
                height = 22.0
            },
            [ordered]@{
                id     = 'plat_upper_bridge'
                type   = 'staticStone'
                x      = 1130.0
                y      = 525.0
                width  = 140.0
                height = 18.0
            },
            [ordered]@{
                id         = 'plat_moving_trials'
                type       = 'movingStone'
                x          = 390.0
                y          = 625.0
                width      = 160.0
                height     = 20.0
                kinematics = [ordered]@{
                    directionX     = 1.0
                    directionY     = 0.0
                    travelDistance = 500.0
                    speed          = 90.0
                }
            }
        )
        spawns       = @(
            [ordered]@{
                id   = 'spawn_dummy_vanguard'
                type = 'training_dummy'
                x    = 2200.0
                y    = 719.0
            }
        )
    }
}

if ($ExportDefault) {
    $targetPath = if ($OutputFile) {
        if ([System.IO.Path]::IsPathRooted($OutputFile)) { $OutputFile } else { Join-Path $root $OutputFile }
    } else {
        Join-Path $root 'assets\dungeons\default_arena.json'
    }

    $parentDir = Split-Path -Parent $targetPath
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $blueprintData = New-DefaultArenaBlueprint
    $json = ConvertTo-Json $blueprintData -Depth 10
    [System.IO.File]::WriteAllText($targetPath, $json)

    Write-Host "Exported default arena blueprint to: $targetPath" -ForegroundColor Green
    exit 0
}

$filesToValidate = @()
if ($InputFile) {
    $fullPath = if ([System.IO.Path]::IsPathRooted($InputFile)) { $InputFile } else { Join-Path $root $InputFile }
    if (-not (Test-Path -LiteralPath $fullPath)) {
        Write-Error "File not found: $InputFile"
        exit 1
    }
    $filesToValidate += (Get-Item -LiteralPath $fullPath)
} else {
    $targetDir = if ([System.IO.Path]::IsPathRooted($Directory)) { $Directory } else { Join-Path $root $Directory }
    if (Test-Path -LiteralPath $targetDir) {
        $filesToValidate += @(Get-ChildItem -LiteralPath $targetDir -Filter '*.json' -Recurse)
    }
}

if ($filesToValidate.Count -eq 0) {
    Write-Host "No blueprint JSON files found to validate in: $Directory" -ForegroundColor Yellow
    exit 0
}

Write-Host "==> Validating $($filesToValidate.Count) arena blueprint(s)..." -ForegroundColor Cyan
$allViolations = @()

foreach ($f in $filesToValidate) {
    try {
        $content = Get-Content -LiteralPath $f.FullName -Raw
        $parsed = ConvertFrom-Json $content
    } catch {
        $allViolations += "$($f.Name): Invalid JSON syntax: $($_.Exception.Message)"
        continue
    }

    $violations = Test-BlueprintObject -bp $parsed -sourceName $f.Name
    if ($violations.Count -gt 0) {
        $allViolations += $violations
    } else {
        Write-Host "  [VALID] $($f.Name) (platforms: $($parsed.platforms.Count), spawns: $($parsed.spawns.Count))" -ForegroundColor Green
    }
}

if ($allViolations.Count -gt 0) {
    Write-Host "`nBlueprint validation FAILED with $($allViolations.Count) violation(s):" -ForegroundColor Red
    foreach ($v in $allViolations) {
        Write-Host "  - $v" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`n[SUCCESS] All $($filesToValidate.Count) arena blueprint(s) validated successfully." -ForegroundColor Green
