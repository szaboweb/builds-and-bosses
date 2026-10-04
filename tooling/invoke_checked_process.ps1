function Invoke-CheckedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [string[]]$Arguments = @(),
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 120,
        [string]$FailurePattern = '',
        [string]$RequiredPattern = ''
    )
    if ($Executable -match '[\\/]' -and -not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        throw "Executable not found: $Executable"
    }
    $stdout = [IO.Path]::GetTempFileName()
    $stderr = [IO.Path]::GetTempFileName()
    $process = $null
    try {
        $start = @{
            FilePath = $Executable
            RedirectStandardOutput = $stdout
            RedirectStandardError = $stderr
            PassThru = $true
            ErrorAction = 'Stop'
        }
        if ($Arguments.Count -gt 0) { $start.ArgumentList = $Arguments }
        $process = Start-Process @start
        $null = $process.Handle
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            throw "Process timeout after ${TimeoutSeconds}s: $Executable"
        }
        $process.WaitForExit()
        $output = (Get-Content -LiteralPath $stdout -Raw) + "`n" +
            (Get-Content -LiteralPath $stderr -Raw)
        $process.Refresh()
        if ($process.ExitCode -ne 0) {
            throw "Process failed (exit $($process.ExitCode)): $Executable`n$output"
        }
        if ($FailurePattern -and $output -match $FailurePattern) {
            throw "Process reported an error despite exit 0: $Executable`n$output"
        }
        if ($RequiredPattern -and $output -notmatch $RequiredPattern) {
            throw "Expected success evidence missing: $Executable`n$output"
        }
        return $output
    } finally {
        if ($null -ne $process) {
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
            }
            if (-not $process.WaitForExit(5000)) {
                throw "Killed process did not exit: PID $($process.Id)"
            }
            $process.Dispose()
        }
        Remove-Item -LiteralPath $stdout, $stderr -Force
    }
}
