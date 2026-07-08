# Ansari Cheats — ek hi file, GitHub se irm run.ps1
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/emadansari2722-max/ANSARI-UPDATE/main/Streamer'
$dllUrl = 'https://github.com/emadansari2722-max/ANSARI-UPDATE/raw/refs/heads/main/Streamer/Streamer.dll'
$dest = "$env:APPDATA\AnsariCheats\launcher\scripts"
$work = "$env:APPDATA\AnsariCheats\launcher"
$state = "$env:APPDATA\AnsariCheats"
$port = 8765
$task = 'AnsariCheatsAutoLauncher'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Admin chahiye — dubara Run as Administrator se chalao' -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null

foreach ($f in @('auto-launcher.ps1', 'remote-panel-server.ps1', 'open-panel.ps1', 'launcher-config.json')) {
    $out = Join-Path $dest $f
    Invoke-WebRequest -Uri "$base/$f" -OutFile $out -UseBasicParsing -TimeoutSec 90
}

$cfgPath = Join-Path $dest 'launcher-config.json'
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
if ($cfg.fallback_dll_url) { $dllUrl = [string]$cfg.fallback_dll_url }
if ($cfg.web_panel_port) { $port = [int]$cfg.web_panel_port }

foreach ($f in @("$state\remote-server.pid", "$work\watcher.lock")) {
    if (Test-Path $f) {
        try { Stop-Process -Id ([int](Get-Content $f -Raw).Trim()) -Force -ErrorAction SilentlyContinue } catch { }
    }
}
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*remote-panel-server*' -or $_.CommandLine -like '*auto-launcher*Watch*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Unregister-ScheduledTask -TaskName BlazeXiterAutoLauncher -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

netsh advfirewall firewall delete rule name="Ansari Cheats Remote Panel" 2>$null | Out-Null
netsh advfirewall firewall add rule name="Ansari Cheats Remote Panel" dir=in action=allow protocol=TCP localport=$port | Out-Null
netsh http delete urlacl url="http://+:$port/" 2>$null | Out-Null
netsh http add urlacl url="http://+:$port/" user="$env:USERDOMAIN\$env:USERNAME" | Out-Null

$p = @{ state = 'idle'; message = 'Inject Panel dabao'; at = (Get-Date -Format o) } | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText("$state\inject_status.json", $p, (New-Object System.Text.UTF8Encoding $false))
Remove-Item "$state\inject_request.json" -Force -ErrorAction SilentlyContinue

$ln = Join-Path $dest 'auto-launcher.ps1'
$args = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ln`" -Watch"
Register-ScheduledTask -TaskName $task -Action (New-ScheduledTaskAction -Execute powershell.exe -Argument $args) -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)) -RunLevel Highest -Force | Out-Null

Start-Process powershell.exe -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', "`"$ln`"", '-Watch') -WindowStyle Hidden
Start-Sleep -Seconds 2
Start-Process powershell.exe -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $dest 'remote-panel-server.ps1')`"") -WindowStyle Hidden

$ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1 -ExpandProperty IPAddress)
if (-not $ip) { $ip = '127.0.0.1' }
$url = "http://${ip}:$port"
$url | Set-Content "$env:USERPROFILE\Desktop\mobile-panel-url.txt" -Encoding UTF8
$url | Set-Content "$state\phone-url.txt" -Encoding UTF8
try { Set-Clipboard -Value $url } catch { }

Write-Host ''
Write-Host '=== Ansari Cheats Ready ===' -ForegroundColor Green
Write-Host "Panel URL: $url" -ForegroundColor Yellow
Write-Host "DLL: $dllUrl" -ForegroundColor DarkGray
Write-Host 'Emulator + FF kholo -> web par Inject Panel -> Login (ansari / 66)' -ForegroundColor Cyan
