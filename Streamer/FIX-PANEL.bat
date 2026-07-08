@echo off
title Ansari Cheats - Panel Fix
echo Purana panel band karke naya panel start ho raha hai...
echo Admin allow karo agar popup aaye.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0restart-panel.ps1\"\"'"
timeout /t 5 >nul
echo.
echo Phone browser me hard refresh karo (Ctrl+F5)
pause
