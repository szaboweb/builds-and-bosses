param(
    [string]$GodotPath = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [switch]$Validate,
    [switch]$Capture,
    [switch]$Editor
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'invoke_checked_process.ps1')
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath. Supply -GodotPath with a Godot 4 executable."
}
if ($Capture -and -not $Validate) {
    throw '-Capture requires -Validate.'
}
if ($Editor -and $Validate) {
    throw 'Choose either -Editor or -Validate.'
}

$projectArgs = @('--path', ('"' + $PSScriptRoot + '"'))
Invoke-CheckedProcess -Executable $GodotPath `
    -Arguments (@('--headless') + $projectArgs + @('--editor', '--import')) `
    -FailurePattern 'SCRIPT ERROR:|ERROR:' -TimeoutSeconds 120

if ($Validate) {
    $argsList = $projectArgs + @('--script', 'res://tests/verify.gd')
    if ($Capture) {
        $argsList += @('--', '--capture')
    } else {
        $argsList = @('--headless') + $argsList
    }
    Invoke-CheckedProcess -Executable $GodotPath -Arguments $argsList `
        -FailurePattern 'SCRIPT ERROR:|ERROR:' `
        -RequiredPattern 'RESULT: \d+ checks; 0 failures' -TimeoutSeconds 300
} else {
    if ($Editor) {
        $projectArgs += '--editor'
    }
    Start-Process -FilePath $GodotPath -ArgumentList $projectArgs | Out-Null
}
