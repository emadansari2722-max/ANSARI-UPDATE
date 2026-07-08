=== ANSARI CHEATS — GitHub Upload (Streamer folder) ===

Repo: emadansari2722-max/ANSARI-UPDATE
Path: main/Streamer/

FILES (sab upload karo):
  Streamer.dll          — cheat DLL (build se)
  run.ps1               — customer one-command setup
  auto-launcher.ps1     — watcher + inject
  remote-panel-server.ps1 — phone web panel
  open-panel.ps1        — panel start
  restart-panel.ps1     — purana panel fix
  launcher-config.json  — config
  FIX-PANEL.bat         — panel UI fix (optional)
  PHONE-URL.bat         — phone URL dikhane ke liye
  SETUP-CMD.txt         — customer PowerShell command
  version.json          — version info

CUSTOMER COMMAND (Admin PowerShell):
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command iex(irm https://raw.githubusercontent.com/emadansari2722-max/ANSARI-UPDATE/main/Streamer/run.ps1)'"

UPDATE: sirf Streamer.dll replace karo GitHub pe
