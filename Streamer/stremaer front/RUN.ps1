# ANSARI CHEATS — client launcher (NO EXE)
# First run: install from GitHub. Next runs: start panel only.

$ErrorActionPreference = 'Stop'

$GitHubRepo = 'emadansari2722-max/ANSARI-UPDATE'
$GitHubBranch = 'main'
$InstallDir = Join-Path $env:LOCALAPPDATA 'AnsariCheats'
$Port = 5000
$Url = "http://127.0.0.1:$Port"

function Test-ServerUp {
    try {
        (Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2).StatusCode -ge 200
    } catch { $false }
}

# Panel already running
if (Test-ServerUp) {
    Start-Process $Url
    exit 0
}

# First time — download panel from GitHub
if (-not (Test-Path (Join-Path $InstallDir 'app.py'))) {
    Write-Host '[*] First setup — downloading from GitHub...'
    $updateUrl = "https://raw.githubusercontent.com/$GitHubRepo/$GitHubBranch/stremaer%20front/UPDATE.ps1"
    $temp = Join-Path $env:TEMP 'ansari_update.ps1'
    Invoke-WebRequest -Uri $updateUrl -OutFile $temp -UseBasicParsing
    & powershell -NoProfile -ExecutionPolicy Bypass -File $temp -GitHubRepo $GitHubRepo -GitHubBranch $GitHubBranch -SkipLaunch
}

# Start panel (Python only — no EXE)
$startScript = Join-Path $InstallDir 'START.ps1'
if (-not (Test-Path $startScript)) {
    Write-Host '[ERROR] Install failed. Install Python 3 from python.org (Add to PATH) and run again.'
    Read-Host 'Press Enter'
    exit 1
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $startScript
