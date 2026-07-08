# Purana panel band karke naya Ansari Cheats panel start karo (Admin chahiye)
param([switch]$Silent)

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8765
$configFile = Join-Path $scriptDir 'launcher-config.json'
if (Test-Path $configFile) {
    try {
        $cfg = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.web_panel_port) { $port = [int]$cfg.web_panel_port }
    } catch { }
}

$serverScript = Join-Path $scriptDir 'remote-panel-server.ps1'
$stateDirs = @("$env:APPDATA\AnsariCheats", "$env:APPDATA\BlazeXiter")

function Get-PanelPidsOnPort([int]$p) {
    $pids = New-Object System.Collections.Generic.HashSet[int]
    $out = netsh http show servicestate 2>&1 | Out-String
    $blocks = $out -split '(?=Request queue name:)'
    foreach ($block in $blocks) {
        if ($block -notmatch ":$p/") { continue }
        foreach ($m in [regex]::Matches($block, 'ID:\s*(\d+)')) {
            [void]$pids.Add([int]$m.Groups[1].Value)
        }
    }
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
        $_.CommandLine -match 'remote-panel-server\.ps1'
    } | ForEach-Object { [void]$pids.Add([int]$_.ProcessId) }
    foreach ($dir in $stateDirs) {
        $pf = Join-Path $dir 'remote-server.pid'
        if (Test-Path $pf) {
            $pidVal = (Get-Content $pf -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($pidVal -match '^\d+$') { [void]$pids.Add([int]$pidVal) }
        }
    }
    return @($pids)
}

function Test-NewPanelUi([int]$p) {
    try {
        $html = (Invoke-WebRequest "http://127.0.0.1:$p/" -UseBasicParsing -TimeoutSec 4).Content
        return ($html -match 'id="loginView"' -and $html -match 'Inject DLL')
    } catch { return $false }
}

function Test-PortOpen([int]$p) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $a = $c.BeginConnect('127.0.0.1', $p, $null, $null)
        if ($a.AsyncWaitHandle.WaitOne(600) -and $c.Connected) { $c.Close(); return $true }
        $c.Close()
    } catch { }
    return $false
}

if (Test-PortOpen $port) {
    if (Test-NewPanelUi $port) {
        if (-not $Silent) { Write-Host 'Naya panel pehle se chal raha hai.' -ForegroundColor Green }
        exit 0
    }
}

foreach ($pidVal in (Get-PanelPidsOnPort $port)) {
    Stop-Process -Id $pidVal -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

netsh http delete urlacl url="http://+:$port/" | Out-Null
netsh http delete urlacl url="http://127.0.0.1:$port/" | Out-Null

foreach ($dir in $stateDirs) {
    Remove-Item (Join-Path $dir 'remote-server.pid') -Force -ErrorAction SilentlyContinue
}

Start-Process powershell.exe -ArgumentList @(
    '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
    '-File', "`"$serverScript`""
) -WindowStyle Hidden

$ok = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    if ((Test-PortOpen $port) -and (Test-NewPanelUi $port)) { $ok = $true; break }
}

if ($ok) {
    if (-not $Silent) { Write-Host 'Naya panel start ho gaya — phone pe refresh karo.' -ForegroundColor Green }
    exit 0
}

if (-not $Silent) { Write-Host 'Panel restart fail — dubara Admin se try karo.' -ForegroundColor Red }
exit 1
