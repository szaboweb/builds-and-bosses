$ErrorActionPreference = 'Stop'
Import-Module PSScriptAnalyzer -RequiredVersion 1.24.0 -ErrorAction Stop
$settings = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'
$files = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -Filter '*.ps1' |
    Where-Object { $_.FullName -notmatch '[\\/](\.dart_tool|\.godot)[\\/]' }
$issues = @($files | ForEach-Object {
    Invoke-ScriptAnalyzer -Path $_.FullName -Settings $settings
})
if ($issues.Count -gt 0) {
    $issues | Format-Table ScriptName, Line, RuleName, Message -AutoSize | Out-Host
    throw "PowerShell analysis failed: $($issues.Count) findings"
}
Write-Host "PowerShell analysis passed: $($files.Count) scripts."
