$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'invoke_checked_process.ps1')
$executable = (Get-Process -Id $PID).Path
$checks = 0
function Invoke-Fixture([string]$Code, [int]$Timeout = 10, [string]$Failure = '', [string]$Required = '') {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Code))
    Invoke-CheckedProcess -Executable $executable `
        -Arguments @('-NoProfile', '-EncodedCommand', $encoded) `
        -TimeoutSeconds $Timeout -FailurePattern $Failure -RequiredPattern $Required
}
function Assert-Fails([scriptblock]$Action, [string]$Message) {
    $caught = $false
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notmatch $Message) { throw }
        $caught = $true
    }
    if (-not $caught) { throw "Expected failure: $Message" }
    $script:checks++
}
$result = Invoke-Fixture 'Write-Output "RESULT: 1 checks; 0 failures"; exit 0' `
    -Required 'RESULT: \d+ checks; 0 failures'
if ($result -notmatch 'RESULT: 1 checks; 0 failures') { throw 'Missing captured output' }
$checks++
Assert-Fails { Invoke-Fixture 'exit 7' } 'exit 7'
Assert-Fails { Invoke-Fixture 'Write-Output "ERROR: bad"; exit 0' -Failure 'ERROR:' } 'despite exit 0'
Assert-Fails { Invoke-Fixture 'exit 0' -Required 'RESULT:' } 'evidence missing'
Assert-Fails { Invoke-Fixture 'Start-Sleep -Seconds 30' -Timeout 1 } 'timeout'
Assert-Fails {
    Invoke-CheckedProcess -Executable (Join-Path $PSScriptRoot 'missing-fixture.exe')
} 'Executable not found'
Write-Host "Checked process tests passed: $checks"
