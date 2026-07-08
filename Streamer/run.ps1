# Ansari Cheats — ek command setup
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/emadansari2722-max/ANSARI-UPDATE/main/Streamer'
$dest = "$env:APPDATA\AnsariCheats\launcher\scripts"
$state = "$env:APPDATA\AnsariCheats"
$work = "$env:APPDATA\AnsariCheats\launcher"
$port = 8765
$task = 'AnsariCheatsAutoLauncher'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Admin PowerShell chahiye' -ForegroundColor Red; exit 1
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($f in @('auto-launcher.ps1', 'remote-panel-server.ps1', 'open-panel.ps1', 'restart-panel.ps1', 'launcher-config.json')) {
    Invoke-WebRequest -Uri "$base/$f" -OutFile (Join-Path $dest $f) -UseBasicParsing -TimeoutSec 90
}

$cfg = Get-Content (Join-Path $dest 'launcher-config.json') -Raw | ConvertFrom-Json
if ($cfg.web_panel_port) { $port = [int]$cfg.web_panel_port }

foreach ($f in @("$state\remote-server.pid", "$work\watcher.lock")) {
    if (Test-Path $f) { try { Stop-Process -Id ([int](Get-Content $f -Raw).Trim()) -Force -EA SilentlyContinue } catch { } }
}
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -EA SilentlyContinue |
    Where-Object { $_.CommandLine -like '*remote-panel-server*' -or $_.CommandLine -like '*auto-launcher*Watch*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
$httpOut = netsh http show servicestate 2>&1 | Out-String
foreach ($block in ($httpOut -split '(?=Request queue name:)')) {
    if ($block -notmatch ":$port/") { continue }
    foreach ($m in [regex]::Matches($block, 'ID:\s*(\d+)')) {
        Stop-Process -Id ([int]$m.Groups[1].Value) -Force -EA SilentlyContinue
    }
}
Unregister-ScheduledTask -TaskName BlazeXiterAutoLauncher -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

netsh advfirewall firewall delete rule name="Ansari Cheats Remote Panel" 2>$null | Out-Null
netsh advfirewall firewall add rule name="Ansari Cheats Remote Panel" dir=in action=allow protocol=TCP localport=$port | Out-Null
netsh http delete urlacl url="http://+:$port/" 2>$null | Out-Null
netsh http add urlacl url="http://+:$port/" user="$env:USERDOMAIN\$env:USERNAME" | Out-Null

Remove-Item "$state\shutdown.flag","$state\web_offline.flag","$state\inject_request.json" -Force -EA SilentlyContinue
$p = @{ state = 'idle'; message = 'Login karo phir Inject DLL dabao'; at = (Get-Date -Format o) } | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText("$state\inject_status.json", $p, (New-Object System.Text.UTF8Encoding $false))

$ln = Join-Path $dest 'auto-launcher.ps1'
$taskArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ln`" -Watch"
Register-ScheduledTask -TaskName $task -Action (New-ScheduledTaskAction -Execute powershell.exe -Argument $taskArgs) -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)) -RunLevel Highest -Force | Out-Null

Start-Process powershell.exe -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', "`"$ln`"", '-Watch') -WindowStyle Hidden
Start-Sleep -Seconds 2
& (Join-Path $dest 'restart-panel.ps1') -Silent | Out-Null

$ip = (Get-NetIPAddress -AddressFamily IPv4 -EA SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1 -ExpandProperty IPAddress)
if (-not $ip) { $ip = '127.0.0.1' }
$url = "http://${ip}:$port"
$url | Set-Content "$env:USERPROFILE\Desktop\mobile-panel-url.txt" -Encoding UTF8
$url | Set-Content "$state\phone-url.txt" -Encoding UTF8
try { Set-Clipboard -Value $url } catch { }

Write-Host ''
Write-Host '=== Ansari Cheats Ready ===' -ForegroundColor Green
Write-Host "Phone URL: $url" -ForegroundColor Yellow
Write-Host '1) Phone se URL kholo  2) Login  3) Inject DLL  4) Aimbot/ESP ON' -ForegroundColor Cyan
