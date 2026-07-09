# ANSARI CHEATS — one-click launcher (Python, no EXE)
$ErrorActionPreference = 'Stop'

# If installed via INSTALL.ps1, run from LocalAppData
$LocalInstall = Join-Path $env:LOCALAPPDATA 'AnsariCheats'
if ((Split-Path -Parent $MyInvocation.MyCommand.Path) -ne $LocalInstall -and (Test-Path (Join-Path $LocalInstall 'app.py'))) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $LocalInstall 'START.ps1')
    exit $LASTEXITCODE
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Port = 5000
$Url = "http://127.0.0.1:$Port"

function Test-ServerUp {
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
        return $r.StatusCode -ge 200
    } catch { return $false }
}

function Wait-Server {
    param([int]$Seconds = 60)
    for ($i = 0; $i -lt $Seconds; $i++) {
        if (Test-ServerUp) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}

if (Test-ServerUp) {
    Start-Process $Url
    exit 0
}

$py = $null
foreach ($cmd in @('py -3', 'python', 'python3')) {
    try {
        $v = Invoke-Expression "$cmd -c `"import sys; print(sys.executable)`"" 2>$null
        if ($v) { $py = $v.Trim(); break }
    } catch {}
}
if (-not $py) {
    Write-Host "[ERROR] Python 3 not found. Install from python.org (Add to PATH)"
    Read-Host "Press Enter"
    exit 1
}

$venvPy = Join-Path $Root '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPy)) {
    & $py -m venv (Join-Path $Root '.venv')
}
& $venvPy -m pip install --upgrade pip -q 2>$null
& $venvPy -m pip install -r (Join-Path $Root 'requirements.txt') -q 2>$null

Start-Process -FilePath $venvPy -ArgumentList (Join-Path $Root 'app.py') -WorkingDirectory $Root -WindowStyle Hidden

if (Wait-Server) {
    Start-Process $Url
} else {
    Write-Host "[WARN] Panel did not start. Try Run as Administrator or check antivirus."
    Read-Host "Press Enter"
}
