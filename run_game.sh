#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINDOWS_BAT="$(wslpath -w "${ROOT_DIR}/run_game.bat")"

exec cmd.exe /c call "${WINDOWS_BAT}"