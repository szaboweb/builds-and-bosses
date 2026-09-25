@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "APP_DIR=%ROOT_DIR%app"

if not exist "%APP_DIR%\pubspec.yaml" (
  echo ERROR: Flutter project not found at "%APP_DIR%"
  exit /b 1
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter is not available on PATH.
  exit /b 1
)

cd /d "%APP_DIR%"
echo Installing Flutter dependencies...
call flutter pub get
if errorlevel 1 exit /b 1

echo Starting Builds ^& Bosses in Chrome at http://localhost:7357/
call flutter run -d chrome --web-port 7357