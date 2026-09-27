$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$python = Join-Path $repoRoot '.venv-2\Scripts\python.exe'
$requirements = Join-Path $PSScriptRoot 'requirements.txt'

if (!(Test-Path $python)) {
  throw "Project Python environment not found at '$python'."
}

& $python -m pip install -r $requirements
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Set-Location $repoRoot
& $python -m uvicorn tooling.character_workshop.server:app --host 127.0.0.1 --port 8765
exit $LASTEXITCODE