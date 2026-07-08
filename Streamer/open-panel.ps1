# Sirf ye command chalao — koi EXE/DLL inject nahi web ke liye.
# Server background me chalega, phone se URL kholo.
# Usage: .\open-panel.ps1 [-Silent]

param([switch]$Silent)

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptDir 'launcher-config.json'
$port = 8765
if (Test-Path $configFile) {
    try {
        $cfg = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.web_panel_port) { $port = [int]$cfg.web_panel_port }
    } catch { }
}
$serverScript = Join-Path $scriptDir 'remote-panel-server.ps1'
$stateDir = "$env:APPDATA\AnsariCheats"
$pidFile = "$stateDir\remote-server.pid"
$urlFile = "$stateDir\remote.url"

function Test-PortOpen([int]$p) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $a = $c.BeginConnect('127.0.0.1', $p, $null, $null)
        if ($a.AsyncWaitHandle.WaitOne(600) -and $c.Connected) { $c.Close(); return $true }
        $c.Close()
    } catch { }
    return $false
}

function Get-LanIp {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
        Select-Object -First 1 -ExpandProperty IPAddress)
    if ($ip) { return $ip }
    return '192.168.1.1'
}

# Pehle se chal raha ho to dubara mat chalao — sirf is port ke liye
if (-not (Test-PortOpen $port)) {
    Start-Process powershell.exe -ArgumentList @(
        '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$serverScript`""
    ) -WindowStyle Hidden

    for ($i = 0; $i -lt 15; $i++) {
        if (Test-PortOpen $port) { break }
        Start-Sleep -Milliseconds 500
    }
}

$lanIp = Get-LanIp
$mobileUrl = "http://${lanIp}:$port"
if (Test-Path $urlFile) {
    $line = Get-Content $urlFile | Where-Object { $_ -like 'mobile=*' } | Select-Object -First 1
    if ($line) { $mobileUrl = $line.Substring(7) }
}

$urlOutDesktop = Join-Path $env:USERPROFILE 'Desktop\mobile-panel-url.txt'
$urlOutAppData = Join-Path $stateDir 'phone-url.txt'

Set-Clipboard -Value $mobileUrl
"$mobileUrl" | Set-Content -Path $urlOutDesktop -Encoding UTF8
"$mobileUrl" | Set-Content -Path $urlOutAppData -Encoding UTF8

$serverOk = Test-PortOpen $port
if ($Silent) {
    if ($serverOk) { Write-Output $mobileUrl }
    else { Write-Error 'Server start failed — run as Administrator'; exit 1 }
}
else {
    if ($serverOk) {
        Write-Host ''
        Write-Host '=== Ansari Cheats Phone URL ===' -ForegroundColor Cyan
        Write-Host $mobileUrl -ForegroundColor Green
        Write-Host 'Clipboard + Desktop file me copy ho gaya.' -ForegroundColor DarkGray
        Write-Host ''
    }
    else {
        Write-Host 'Server start nahi hua — PowerShell Admin se try karo.' -ForegroundColor Red
        exit 1
    }
}
