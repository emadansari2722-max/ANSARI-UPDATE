@echo off
title Build AnsariCheats.exe
cd /d "%~dp0"

where py >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Install Python 3 from python.org first
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo [INFO] Creating venv...
  py -m venv .venv || exit /b 1
)

echo [INFO] Installing build dependencies...
".venv\Scripts\python.exe" -m pip install --upgrade pip pyinstaller -q
".venv\Scripts\python.exe" -m pip install -r requirements.txt -q

if not exist "AotBst.dll" (
  echo [ERROR] AotBst.dll missing - copy from AOSTBST folder first
  pause
  exit /b 1
)

echo [INFO] Building portable EXE (may take 2-5 min)...
".venv\Scripts\python.exe" -m PyInstaller --noconfirm --clean app.spec || exit /b 1

copy /Y "dist\AnsariCheats.exe" "AnsariCheats.exe" >nul 2>&1
echo.
echo [OK] Ready for customers:
echo   dist\AnsariCheats.exe
echo   AnsariCheats.exe  (copy in folder)
echo   Give users START.bat — double-click only, no Python needed.
echo.
pause
