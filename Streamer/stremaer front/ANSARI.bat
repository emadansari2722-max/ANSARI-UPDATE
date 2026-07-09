@echo off
title ANSARI CHEATS
REM Client file — NO EXE. Only this .bat or the PowerShell line below.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN.ps1"
if errorlevel 1 pause
