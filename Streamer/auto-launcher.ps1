# Ansari Cheats Auto Launcher
# GitHub se DLL download -> version check -> inject -> web panel -> emulator close pe cleanup
# One-shot:  powershell -ExecutionPolicy Bypass -File "...\auto-launcher.ps1"
# Always-on: powershell -ExecutionPolicy Bypass -File "...\auto-launcher.ps1" -Watch
# Ek baar setup: SETUP-CMD.txt wala ek PowerShell command
# Koi popup nahi — log: %APPDATA%\AnsariCheats\launcher\launcher.log

param(
    [switch]$Verbose,
    [switch]$Watch
)

$ErrorActionPreference = 'SilentlyContinue'
$Silent = -not $Verbose
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptDir 'launcher-config.json'
$openPanelScript = Join-Path $scriptDir 'open-panel.ps1'
$workDir = "$env:APPDATA\AnsariCheats\launcher"
$blazeDir = "$env:APPDATA\AnsariCheats"
$injectRequestFile = Join-Path $blazeDir 'inject_request.json'
$injectStatusFile = Join-Path $blazeDir 'inject_status.json'
$injectedPidFile = Join-Path $workDir 'last_injected_pid.txt'
$versionFile = Join-Path $workDir 'installed_version.txt'
$dllPath = Join-Path $workDir 'payload.dll'
$logFile = Join-Path $workDir 'launcher.log'

function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

function Clear-LauncherLogs {
    $paths = @(
        $logFile,
        "$workDir\download.log",
        "$env:USERPROFILE\Desktop\mobile-panel-url.txt",
        "$env:APPDATA\AnsariCheats\game_heartbeat.txt",
        "$env:APPDATA\AnsariCheats\web_auth_request.json"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }
}

function Get-Config {
    if (-not (Test-Path $configFile)) {
        throw "Config missing: $configFile"
    }
    return Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-InstalledVersion {
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }
    return ''
}

function Set-InstalledVersion($ver) {
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null
    Set-Content -Path $versionFile -Value $ver -Encoding UTF8 -NoNewline
}

function Initialize-KeyAuthSession($cfg) {
    $base = if ($cfg.keyauth_api_url) { [string]$cfg.keyauth_api_url } else { 'https://keyauth.win/api/1.2/' }
    if (-not $base.EndsWith('/')) { $base += '/' }
    $appName = [string]$cfg.keyauth_name
    $owner = [string]$cfg.keyauth_ownerid
    $ver = [uri]::EscapeDataString([string]$cfg.keyauth_version)
    $url = "${base}?type=init&name=$([uri]::EscapeDataString($appName))&ownerid=$owner&ver=$ver"
    $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 20
    if (-not $resp.success) {
        throw "KeyAuth init failed: $($resp.message)"
    }
    return @{
        SessionId = [string]$resp.sessionid
        BaseUrl   = $base
        Name      = $appName
        OwnerId   = $owner
    }
}

function Get-KeyAuthVariable($session, $varId) {
    if (-not $varId) { return $null }
    foreach ($vid in @([string]$varId)) {
        if (-not $vid) { continue }
        $body = @{
            type      = 'var'
            varid     = $vid
            sessionid = $session.SessionId
            name      = [string]$session.Name
            ownerid   = [string]$session.OwnerId
        }
        try {
            $resp = Invoke-RestMethod -Uri $session.BaseUrl -Method Post -Body $body -TimeoutSec 20
            if ($resp.success) { return [string]$resp.message }
            Write-Log "KeyAuth var '$vid' failed: $($resp.message)"
        } catch {
            Write-Log "KeyAuth var '$vid' error: $($_.Exception.Message)"
        }
    }
    return $null
}

function Get-KeyAuthVarIds($cfg, $kind) {
    if ($kind -eq 'version') {
        $ids = @([string]$cfg.keyauth_var_version_id, [string]$cfg.keyauth_var_version) | Where-Object { $_ }
    } else {
        $ids = @([string]$cfg.keyauth_var_url_id, [string]$cfg.keyauth_var_url) | Where-Object { $_ }
    }
    return $ids
}

function Get-RemoteReleaseInfo($cfg) {
    try {
        $session = Initialize-KeyAuthSession $cfg
        $remoteVer = $null
        $remoteUrl = $null
        foreach ($id in (Get-KeyAuthVarIds $cfg 'version')) {
            $remoteVer = Get-KeyAuthVariable $session $id
            if ($remoteVer) { break }
        }
        foreach ($id in (Get-KeyAuthVarIds $cfg 'url')) {
            $remoteUrl = Get-KeyAuthVariable $session $id
            if ($remoteUrl) { break }
        }
        if ($remoteVer -and $remoteUrl) {
            Write-Log "KeyAuth vars: version=$remoteVer"
            return @{
                version = $remoteVer.Trim()
                dll_url = $remoteUrl.Trim()
                source  = 'keyauth'
            }
        }
    } catch {
        Write-Log "KeyAuth error: $($_.Exception.Message)"
    }

    if ($cfg.github_version_url -and [string]$cfg.github_version_url -notmatch 'YOUR_USER') {
        try {
            $raw = Invoke-RestMethod -Uri [string]$cfg.github_version_url -Method Get -TimeoutSec 20
            if ($raw) {
                return @{
                    version = [string]$raw.version
                    dll_url = [string]$raw.dll_url
                    source  = 'github'
                }
            }
        } catch {
            Write-Log "GitHub version.json error: $($_.Exception.Message)"
        }
    }

    if ($cfg.fallback_dll_url) {
        $ver = if ($cfg.fallback_version) { [string]$cfg.fallback_version } else { [string]$cfg.keyauth_version }
        return @{
            version = $ver
            dll_url = [string]$cfg.fallback_dll_url
            source  = 'fallback'
        }
    }

    return $null
}

function Resolve-DownloadUrl($cfg, $remoteInfo) {
    if ($remoteInfo -and $remoteInfo.dll_url) {
        return [string]$remoteInfo.dll_url, [string]$remoteInfo.version
    }
    $fallback = [string]$cfg.local_dll_fallback
    if (Test-Path $fallback) {
        return $fallback, (Get-InstalledVersion)
    }
    return $null, $null
}

function Extract-DllFromZip($zipPath, $dest) {
    $temp = Join-Path $env:TEMP ("ansari-zip-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    try {
        Expand-Archive -Path $zipPath -DestinationPath $temp -Force
        $dll = Get-ChildItem -Path $temp -Recurse -Filter '*.dll' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Streamer|ansari' } |
            Sort-Object Length -Descending |
            Select-Object -First 1
        if (-not $dll) { throw 'ZIP me DLL nahi mili' }
        Copy-Item -Path $dll.FullName -Destination $dest -Force
        Write-Log "Extracted DLL from zip: $($dll.FullName)"
    } finally {
        Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Download-Dll($url, $dest) {
    Write-Log "Downloading: $url"
    if ($url -match '\.zip($|\?)') {
        $tmpZip = Join-Path $env:TEMP ("ansari-dl-" + [guid]::NewGuid().ToString('N') + '.zip')
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing -TimeoutSec 300
            if (-not (Test-Path $tmpZip)) { throw 'Download failed' }
            if ((Get-Item $tmpZip).Length -lt 10000) { throw 'Downloaded zip too small' }
            Extract-DllFromZip $tmpZip $dest
        } finally {
            Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        }
    } else {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 300
    }
    if (-not (Test-Path $dest)) { throw 'Download failed' }
    if ((Get-Item $dest).Length -lt 10000) { throw 'Downloaded file too small' }
}

function Copy-LocalDll($src, $dest) {
    Copy-Item -Path $src -Destination $dest -Force
}

function Ensure-Dll($cfg) {
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null
    $installed = Get-InstalledVersion
    $remoteInfo = Get-RemoteReleaseInfo $cfg
    if (-not $remoteInfo) { throw 'Could not get version/URL from KeyAuth or fallback' }

    $targetVer = [string]$remoteInfo.version
    $needDownload = (-not (Test-Path $dllPath)) -or ($installed -ne $targetVer)
    if (-not $needDownload) {
        Write-Log "DLL up to date ($installed) via $($remoteInfo.source)"
        return $dllPath
    }

    Write-Log "Update needed: installed=$installed target=$targetVer source=$($remoteInfo.source)"
    $url, $verFromUrl = Resolve-DownloadUrl $cfg $remoteInfo
    if (-not $url) { throw 'No DLL URL and no local fallback' }

    if ($url -like 'http*') {
        Download-Dll $url $dllPath
    } else {
        Copy-LocalDll $url $dllPath
    }

    $finalVer = if ($targetVer) { $targetVer } else { $verFromUrl }
    if (-not $finalVer) { $finalVer = (Get-Date -Format 'yyyyMMddHHmmss') }
    Set-InstalledVersion $finalVer
    Write-Log "DLL ready version=$finalVer"
    return $dllPath
}

function Wait-EmulatorProcess($names, [int]$maxAttempts = 180) {
    Write-Log 'Waiting for emulator...'
    $i = 0
    while ($true) {
        foreach ($n in $names) {
            $p = Get-Process -Name $n -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($p) {
                Write-Log "Emulator found: $($p.ProcessName) pid=$($p.Id)"
                return $p
            }
        }
        $i++
        if ($maxAttempts -gt 0 -and $i -ge $maxAttempts) { return $null }
        Start-Sleep -Seconds 2
    }
}

# Embedded x64 DLL injector (LoadLibraryW)
if (-not ('BlazeInject.Injector' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace BlazeInject {
    public static class Injector {
        const uint PROCESS_ALL_ACCESS = 0x1F0FFF;
        const uint MEM_COMMIT = 0x1000;
        const uint MEM_RESERVE = 0x2000;
        const uint PAGE_READWRITE = 0x04;

        [DllImport("kernel32.dll", SetLastError=true)]
        static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", SetLastError=true)]
        static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);

        [DllImport("kernel32.dll", SetLastError=true)]
        static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, out IntPtr lpThreadId);

        [DllImport("kernel32.dll", CharSet=CharSet.Ansi, SetLastError=true)]
        static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern IntPtr GetModuleHandleW(string lpModuleName);

        [DllImport("kernel32.dll", SetLastError=true)]
        static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool CloseHandle(IntPtr hObject);

        public static bool Inject(int pid, string dllPath) {
            if (string.IsNullOrWhiteSpace(dllPath) || !System.IO.File.Exists(dllPath)) return false;
            IntPtr hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
            if (hProcess == IntPtr.Zero) return false;

            byte[] pathBytes = Encoding.Unicode.GetBytes(dllPath + "\0");
            IntPtr alloc = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)pathBytes.Length, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
            if (alloc == IntPtr.Zero) { CloseHandle(hProcess); return false; }

            UIntPtr written;
            if (!WriteProcessMemory(hProcess, alloc, pathBytes, (uint)pathBytes.Length, out written)) {
                CloseHandle(hProcess); return false;
            }

            IntPtr k32 = GetModuleHandleW("kernel32.dll");
            IntPtr loadLib = GetProcAddress(k32, "LoadLibraryW");
            if (loadLib == IntPtr.Zero) { CloseHandle(hProcess); return false; }

            IntPtr hThread;
            IntPtr remote = CreateRemoteThread(hProcess, IntPtr.Zero, 0, loadLib, alloc, 0, out hThread);
            if (remote == IntPtr.Zero) { CloseHandle(hProcess); return false; }

            WaitForSingleObject(remote, 15000);
            CloseHandle(remote);
            CloseHandle(hProcess);
            return true;
        }
    }
}
'@
}

function Inject-Dll($process, $dll) {
  if (Test-Path $injectedPidFile) {
      $oldPid = [int](Get-Content $injectedPidFile -Raw).Trim()
      if ($oldPid -eq [int]$process.Id) {
          throw 'Is emulator me DLL pehle se injected hai — crash se bachne ke liye emulator band karke dubara kholo'
      }
  }
  $fullDll = (Resolve-Path $dll).Path
  Write-Log "Injecting into pid=$($process.Id) dll=$fullDll"
  $ok = [BlazeInject.Injector]::Inject([int]$process.Id, $fullDll)
  if (-not $ok) { throw 'Injection failed — run PowerShell as Administrator' }
  Set-Content -Path $injectedPidFile -Value $process.Id -Encoding UTF8 -NoNewline
  Write-Log 'Injection OK'
}

function Clear-InjectedPid {
    if (Test-Path $injectedPidFile) {
        Remove-Item $injectedPidFile -Force -ErrorAction SilentlyContinue
    }
}

function Wait-ForFreshEmulator($names, [int]$excludePid) {
    Write-Log "Waiting for fresh emulator (avoid pid=$excludePid)..."
    Set-InjectStatus 'waiting_emulator' 'Emulator RESTART karo — pura band karke dubara kholo'
    for ($i = 0; $i -lt 600; $i++) {
        $oldAlive = $false
        if ($excludePid -gt 0) {
            $oldAlive = [bool](Get-Process -Id $excludePid -ErrorAction SilentlyContinue)
        }
        foreach ($n in $names) {
            $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
            foreach ($p in $procs) {
                if ($excludePid -gt 0 -and $p.Id -eq $excludePid -and $oldAlive) { continue }
                Write-Log "Fresh emulator: $($p.ProcessName) pid=$($p.Id)"
                return $p
            }
        }
        Start-Sleep -Seconds 2
    }
    return $null
}

function Wait-ForDllUnload([int]$staleSeconds = 4, [int]$maxWaitSeconds = 45) {
    $hb = "$env:APPDATA\AnsariCheats\game_heartbeat.txt"
    Write-Log "Waiting for DLL unload (heartbeat stale ${staleSeconds}s)..."
    $lastSeen = $null
    $lastChange = Get-Date
    $deadline = (Get-Date).AddSeconds($maxWaitSeconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-Path $hb)) {
            Write-Log 'Heartbeat gone — DLL unloaded'
            return $true
        }
        $raw = (Get-Content $hb -Raw -ErrorAction SilentlyContinue).Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Start-Sleep -Seconds 1
            continue
        }
        if ($raw -ne $lastSeen) {
            $lastSeen = $raw
            $lastChange = Get-Date
        } elseif (((Get-Date) - $lastChange).TotalSeconds -ge $staleSeconds) {
            Write-Log 'Heartbeat stale — DLL unloaded'
            return $true
        }
        Start-Sleep -Seconds 1
    }
    Write-Log 'DLL unload wait timeout — continuing carefully'
    return $false
}

function Start-WebPanel {
    if (Test-Path $openPanelScript) {
        Write-Log 'Starting web panel'
        Start-Process powershell.exe -ArgumentList @(
            '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
            '-File', "`"$openPanelScript`"", '-Silent'
        ) -WindowStyle Hidden
    }
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

function Get-PanelPort {
    $cfg = Get-Config
    if ($cfg.web_panel_port) { return [int]$cfg.web_panel_port }
    return 8765
}

function Ensure-WebPanelRunning {
    $panelPort = Get-PanelPort
    if (Test-PortOpen $panelPort) {
        Write-Log 'Web panel already running'
        return
    }
    Start-WebPanel
    for ($i = 0; $i -lt 20; $i++) {
        if (Test-PortOpen $panelPort) {
            Write-Log 'Web panel ready'
            return
        }
        Start-Sleep -Milliseconds 500
    }
    Write-Log 'Web panel start slow — continuing'
}

function Set-InjectStatus($state, $message) {
    New-Item -ItemType Directory -Force -Path $blazeDir | Out-Null
    $payload = @{
        state   = [string]$state
        message = [string]$message
        at      = (Get-Date -Format 'o')
    } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($injectStatusFile, $payload, (New-Object System.Text.UTF8Encoding $false))
}

function Wait-ForInjectRequest {
    Write-Log 'Waiting for web inject request...'
    Set-InjectStatus 'idle' 'Web panel se Inject Panel dabao'
    while ($true) {
        if (Test-Path $injectRequestFile) {
            Remove-Item $injectRequestFile -Force -ErrorAction SilentlyContinue
            Write-Log 'Inject request received from web panel'
            return
        }
        Start-Sleep -Seconds 1
    }
}

function Send-ShutdownSignal {
    $flag = "$env:APPDATA\AnsariCheats\shutdown.flag"
    Set-Content -Path $flag -Value (Get-Date -Format 'o') -Encoding UTF8
    Write-Log 'Shutdown signal sent'
}

function Clear-StaleDllSignals {
    foreach ($p in @(
        "$blazeDir\shutdown.flag",
        "$blazeDir\game_heartbeat.txt",
        "$blazeDir\web_offline.flag"
    )) {
        if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }
    Write-Log 'Cleared stale DLL signal files'
}

function Watch-EmulatorExit($process, $names) {
    $watchedPid = [int]$process.Id
    Write-Log "Watching emulator pid=$watchedPid"
    while ($true) {
        if (Test-Path $injectRequestFile) {
            Remove-Item $injectRequestFile -Force -ErrorAction SilentlyContinue
            Write-Log 'Inject/Reconnect requested from web panel'
            return 'reconnect'
        }

        $alive = Get-Process -Id $watchedPid -ErrorAction SilentlyContinue
        if ($alive) {
            Start-Sleep -Seconds 1
            continue
        }

        $current = $null
        foreach ($n in $names) {
            $current = Get-Process -Name $n -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($current) { break }
        }
        if (-not $current) {
            Write-Log 'Emulator fully closed'
            return 'exit'
        }
        if ([int]$current.Id -ne $watchedPid) {
            Write-Log "Emulator new pid=$($current.Id) (was $watchedPid)"
            return 'reconnect'
        }
        Start-Sleep -Seconds 1
    }
}

function Find-EmulatorProcess($names) {
    foreach ($n in $names) {
        $p = Get-Process -Name $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) {
            Write-Log "Emulator found (fast): $($p.ProcessName) pid=$($p.Id)"
            return $p
        }
    }
    return $null
}

function Invoke-LightReconnectCleanup {
    Send-ShutdownSignal
    Start-Sleep -Seconds 2
    Wait-ForDllUnload | Out-Null
    Clear-StaleDllSignals
    Write-Log 'Light cleanup for reconnect'
}

function Reset-WebPanelState {
    $stateDir = "$env:APPDATA\AnsariCheats"
    $stateFile = "$stateDir\web_remote_state.json"
    $offlineFlag = "$stateDir\web_offline.flag"
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

    $defaults = @{
        stream_proof = $true
        aim_enable = $false
        aim_fov_draw = $false
        aim_fov = 100
        aim_range = 500
        aim_safe = $false
        aim_safe_delay = 0
        aim_type = 0
        ignore_knocked = $false
        no_recoil = $false
        fast_reload = $false
        esp_enable = $false
        esp_snaplines = $false
        esp_line_pos = 0
        esp_box = $false
        esp_health_bar = $false
        esp_health_pos = 2
        esp_name = $false
        esp_distance = $false
        esp_weapon_icon = $false
        esp_skeleton = $false
        esp_health_text = $false
        esp_weapon_text = $false
        esp_distance_slider = 300
        esp_refresh = $false
        loot_esp = $false
        loot_range = 300
        rapid_fire = $false
        fire_speed = 50
        sniper_scope = $false
        scope_target = 0
        speed_internal = $false
        spin_bot = $false
        spin_speed = 4.2
        snap_pull = $false
        pull_speed = 0
        pull_strength = 0.5
        limit_fps = $false
        max_fps = 60
        reduce_gpu = $true
        mute_beep = $false
    }
    $json = $defaults | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($stateFile, $json, (New-Object System.Text.UTF8Encoding $false))
    Set-Content -Path $offlineFlag -Value (Get-Date -Format 'o') -Encoding UTF8
    $clientAlive = Join-Path $stateDir 'web_client_alive.txt'
    if (Test-Path $clientAlive) { Remove-Item $clientAlive -Force -ErrorAction SilentlyContinue }
    Write-Log 'Web panel state reset — all features OFF'
}

function Stop-WebServer {
    Reset-WebPanelState
    $pidFile = "$env:APPDATA\AnsariCheats\remote-server.pid"
    if (Test-Path $pidFile) {
        $spid = [int](Get-Content $pidFile -Raw)
        Stop-Process -Id $spid -Force -ErrorAction SilentlyContinue
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Cleanup {
    Send-ShutdownSignal
    if ($Watch) {
        Reset-WebPanelState
    } else {
        Stop-WebServer
    }
    Start-Sleep -Seconds 1
    Clear-InjectedPid
    $paths = @(
        "$env:USERPROFILE\Desktop\mobile-panel-url.txt",
        "$env:APPDATA\AnsariCheats\game_heartbeat.txt",
        "$env:APPDATA\AnsariCheats\web_auth_request.json"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }
    $shutdown = "$blazeDir\shutdown.flag"
    if (Test-Path $shutdown) { Remove-Item $shutdown -Force -ErrorAction SilentlyContinue }
    Write-Log 'Cleanup done'
}

function Test-WatcherAlreadyRunning {
    $lockFile = Join-Path $workDir 'watcher.lock'
    if (-not (Test-Path $lockFile)) { return $false }
    try {
        $oldPid = [int](Get-Content $lockFile -Raw).Trim()
        if ($oldPid -le 0) { return $false }
        $p = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        return [bool]$p
    } catch { return $false }
}

function Set-WatcherLock {
    $lockFile = Join-Path $workDir 'watcher.lock'
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null
    Set-Content -Path $lockFile -Value $PID -Encoding UTF8 -NoNewline
}

function Clear-WatcherLock {
    $lockFile = Join-Path $workDir 'watcher.lock'
    if (Test-Path $lockFile) { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue }
}

function Invoke-Session {
    param($cfg)

    $dll = Ensure-Dll $cfg
    $waitLimit = if ($Watch) { 0 } else { 180 }
    $emu = Wait-EmulatorProcess $cfg.emulator_processes $waitLimit
    if (-not $emu) { throw 'Emulator not found — start game first' }

    Start-Sleep -Seconds 3
    Clear-StaleDllSignals
    Inject-Dll $emu $dll
    Start-Sleep -Seconds 2
    if (-not $Watch) { Start-WebPanel }

    Watch-EmulatorExit $emu $cfg.emulator_processes
    Invoke-Cleanup
    Write-Log 'Session ended — emulator closed'
}

function Invoke-WatchInjectSession {
    param($cfg)

    $fastFind = $false
    $lastEmuPid = 0
    while ($true) {
        if (-not $fastFind) {
            Set-InjectStatus 'downloading' 'Step 1/3: DLL download ho rahi hai...'
        } else {
            Set-InjectStatus 'reconnecting' 'Reconnect — purani DLL band ho rahi hai...'
            Invoke-LightReconnectCleanup
            Wait-ForDllUnload | Out-Null
            Clear-InjectedPid
        }

        $dll = Ensure-Dll $cfg

        if ($fastFind) {
            Set-InjectStatus 'reconnecting' 'Reconnect — emulator check ho raha hai...'
            $emu = $null
            if ($lastEmuPid -gt 0) {
                $emu = Get-Process -Id $lastEmuPid -ErrorAction SilentlyContinue
            }
            if ($emu) {
                Set-InjectStatus 'reconnecting' 'Reconnect — same emulator me dubara inject...'
            } else {
                $emu = Wait-ForFreshEmulator $cfg.emulator_processes $lastEmuPid
            }
        } else {
            Set-InjectStatus 'waiting_emulator' 'Step 2/3: Emulator start karo (BlueStacks / MSI)...'
            $emu = Wait-EmulatorProcess $cfg.emulator_processes 0
        }
        if (-not $emu) { throw 'Emulator not found — pehle emulator kholo' }

        Set-InjectStatus 'injecting' 'Step 3/3: Free Fire lobby me ho to best — inject ho rahi hai...'
        Start-Sleep -Seconds 8
        Clear-StaleDllSignals
        try {
            Inject-Dll $emu $dll
        } catch {
            if ($fastFind -and $lastEmuPid -gt 0) {
                Write-Log "Same-PID inject blocked — waiting for emulator restart: $($_.Exception.Message)"
                Clear-InjectedPid
                Set-InjectStatus 'waiting_emulator' 'Emulator RESTART karo — pura band karke dubara kholo'
                $emu = Wait-ForFreshEmulator $cfg.emulator_processes $lastEmuPid
                if (-not $emu) { throw 'Emulator restart timeout — emulator band karke dubara kholo' }
                Inject-Dll $emu $dll
            } else {
                throw
            }
        }
        Start-Sleep -Seconds 2
        $lastEmuPid = [int]$emu.Id

        if ($fastFind) {
            Set-InjectStatus 'injected' 'Reconnect SUCCESS — panel dubara connect ho gaya'
        } else {
            Set-InjectStatus 'injected' 'SUCCESS — DLL inject ho gaya! Ab license login karo'
        }

        $watchResult = Watch-EmulatorExit $emu $cfg.emulator_processes
        if ($watchResult -eq 'exit') {
            Clear-InjectedPid
            Invoke-Cleanup
            Set-InjectStatus 'idle' 'Emulator band — dubara Inject Panel dabao'
            Write-Log 'Watch inject session ended'
            $fastFind = $false
            $lastEmuPid = 0
            return
        }

        Write-Log 'Reconnect loop — reconnect requested from web'
        $fastFind = $true
    }
}

# ── Main ──
if ($Watch) {
    if (Test-WatcherAlreadyRunning) {
        Write-Log 'Watcher already running — exit'
        exit 0
    }
    Set-WatcherLock
    Write-Log '=== Watcher mode start (web-triggered inject) ==='
    try {
        $cfg = Get-Config
        Ensure-WebPanelRunning
        Set-InjectStatus 'idle' 'Web panel kholo — Inject Panel dabao'
        while ($true) {
            try {
                Wait-ForInjectRequest
                Invoke-WatchInjectSession $cfg
                Start-Sleep -Seconds 3
            } catch {
                Write-Log "Inject session error: $($_.Exception.Message)"
                Set-InjectStatus 'error' ("FAILED — " + $_.Exception.Message)
                Invoke-Cleanup
                Start-Sleep -Seconds 8
                Set-InjectStatus 'idle' 'Web panel se dubara Inject Panel dabao'
            }
        }
    } finally {
        Clear-WatcherLock
    }
    exit 0
}

try {
    if (-not $Watch) { Clear-LauncherLogs }
    Write-Log '=== Auto launcher start (one-shot) ==='
    $cfg = Get-Config
    Invoke-Session $cfg
    Write-Log 'Done — run again or use -Watch / ansari-install.ps1'
    if (-not $Silent) {
        Write-Host 'Emulator band — cleanup ho gaya.' -ForegroundColor Yellow
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Invoke-Cleanup
    if (-not $Silent) {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    exit 1
}
