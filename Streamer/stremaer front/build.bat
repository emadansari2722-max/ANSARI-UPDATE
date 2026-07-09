@echo off
setlocal enabledelayedexpansion

REM === CONFIG ===
set "ENTRY=detectionbypass.py"
set "APP_NAME=MyApp"
set "ICON="
REM Example icon: set "ICON=app.ico"

REM === SETUP ===
cd /d "%~dp0"

where py >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Python not found. Install Python and re-open terminal.
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo [INFO] Creating venv...
  py -m venv .venv || exit /b 1
)

echo [INFO] Installing build deps...
".venv\Scripts\python.exe" -m pip install --upgrade pip pyinstaller || exit /b 1

if not exist "%ENTRY%" (
  echo [ERROR] Entry file not found: %ENTRY%
  exit /b 1
)

echo [INFO] Building EXE...
set "ICON_ARG="
if not "%ICON%"=="" set "ICON_ARG=--icon=%ICON%"

".venv\Scripts\python.exe" -m PyInstaller ^
  --noconfirm --clean ^
  --onefile ^
  --name "%APP_NAME%" ^
  %ICON_ARG% ^
  "%ENTRY%" || exit /b 1

echo.
echo [OK] Built: dist\%APP_NAME%.exe
pause