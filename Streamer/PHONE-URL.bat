@echo off
title Ansari Cheats — Phone URL
cd /d "%~dp0"

for /f "usebackq delims=" %%P in (`powershell -NoProfile -WindowStyle Hidden -Command "$c='%~dp0launcher-config.json'; if(Test-Path $c){(Get-Content $c -Raw|ConvertFrom-Json).web_panel_port}else{8765}"`) do set "PORT=%%P"
set "IP="

for /f "usebackq delims=" %%I in (`powershell -NoProfile -WindowStyle Hidden -Command "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1 -ExpandProperty IPAddress)"`) do set "IP=%%I"

if not defined IP (
    echo PC ka WiFi/LAN IP nahi mila.
    echo WiFi ON karke dubara try karo.
    pause
    exit /b 1
)

set "URL=http://%IP%:%PORT%"

echo.
echo  ========================================
echo   PHONE URL  ^(same WiFi par kholo^)
echo  ========================================
echo.
echo   %URL%
echo.
echo  Clipboard me copy ho gaya.
echo.

powershell -NoProfile -WindowStyle Hidden -Command "Set-Clipboard -Value '%URL%'" >nul 2>&1
echo %URL%> "%USERPROFILE%\Desktop\mobile-panel-url.txt"
if not exist "%APPDATA%\AnsariCheats" mkdir "%APPDATA%\AnsariCheats" >nul 2>&1
echo %URL%> "%APPDATA%\AnsariCheats\phone-url.txt"

pause
