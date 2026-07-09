# ANSARI CHEATS — client installer (host this file on GitHub)
# Owner: change $GitHubRepo below, then push to GitHub.

param()

$ErrorActionPreference = 'Stop'

# ========== OWNER: SET YOUR GITHUB REPO ==========
$GitHubRepo = "emadansari2722-max/ANSARI-UPDATE"
$GitHubBranch = "main"
# ================================================

if ($GitHubRepo -match 'YOUR_GITHUB') {
    Write-Host "[ERROR] Owner must edit INSTALL.ps1 and set `$GitHubRepo before clients use this."
    Read-Host "Press Enter"
    exit 1
}

$updateUrl = "https://raw.githubusercontent.com/$GitHubRepo/$GitHubBranch/stremaer%20front/UPDATE.ps1"
$tempScript = Join-Path $env:TEMP "ansari_update.ps1"

Write-Host "[*] ANSARI CHEATS — downloading installer..."
Invoke-WebRequest -Uri $updateUrl -OutFile $tempScript -UseBasicParsing

& powershell -NoProfile -ExecutionPolicy Bypass -File $tempScript -GitHubRepo $GitHubRepo -GitHubBranch $GitHubBranch
