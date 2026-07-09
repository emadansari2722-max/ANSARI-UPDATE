# GitHub install + KeyAuth auto-update
param(
    [string]$KeyAuthDownloadUrl = "",
    [string]$GitHubRepo = "",
    [string]$GitHubBranch = "main",
    [switch]$SkipLaunch
)

$ErrorActionPreference = 'Stop'

function Get-Config {
    param([string]$RepoOverride, [string]$BranchOverride)
    $cfgPath = Join-Path $PSScriptRoot 'update_config.json'
    $cfg = $null
    if (Test-Path $cfgPath) {
        $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    } else {
        $cfg = [pscustomobject]@{
            github_repo     = 'YOUR_GITHUB_USERNAME/YOUR_REPO_NAME'
            github_branch   = 'main'
            install_folder  = 'AnsariCheats'
        }
    }
    if ($RepoOverride) { $cfg | Add-Member -NotePropertyName github_repo -NotePropertyValue $RepoOverride -Force }
    if ($BranchOverride) { $cfg | Add-Member -NotePropertyName github_branch -NotePropertyValue $BranchOverride -Force }
    return $cfg
}

function Find-PanelRoot {
    param([string]$SearchRoot)
    $hit = Get-ChildItem -Path $SearchRoot -Recurse -Filter 'app.py' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.DirectoryName 'keyauth.py') } |
        Select-Object -First 1
    if (-not $hit) { throw "app.py not found in downloaded package" }
    return $hit.Directory.FullName
}

function Sync-PanelFiles {
    param([string]$SourceDir, [string]$TargetDir)
    if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
    $exclude = @('.venv', 'build', 'dist', '__pycache__', '.git', 'app.build', 'app.dist')
    Get-ChildItem -Path $SourceDir -Force | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        $dest = Join-Path $TargetDir $_.Name
        if ($_.PSIsContainer) {
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Copy-Item $_.FullName $dest -Recurse -Force
        } else {
            Copy-Item $_.FullName $dest -Force
        }
    }
}

function Ensure-Python {
    foreach ($cmd in @('py -3', 'python', 'python3')) {
        try {
            $exe = Invoke-Expression "$cmd -c `"import sys; print(sys.executable)`"" 2>$null
            if ($exe) { return $exe.Trim() }
        } catch {}
    }
    throw "Python 3 required. Install from python.org (Add to PATH), then run again."
}

function Ensure-Venv {
    param([string]$PanelDir, [string]$PythonExe)
    $venvPy = Join-Path $PanelDir '.venv\Scripts\python.exe'
    if (-not (Test-Path $venvPy)) {
        & $PythonExe -m venv (Join-Path $PanelDir '.venv')
    }
    & $venvPy -m pip install --upgrade pip -q
    & $venvPy -m pip install -r (Join-Path $PanelDir 'requirements.txt') -q
    return $venvPy
}

function Install-FromZip {
    param([string]$ZipUrl, [string]$InstallDir)
    $tempZip = Join-Path $env:TEMP ("ansari_" + [guid]::NewGuid().ToString() + ".zip")
    $tempExtract = Join-Path $env:TEMP ("ansari_" + [guid]::NewGuid().ToString())
    Write-Host "[*] Downloading..."
    Invoke-WebRequest -Uri $ZipUrl -OutFile $tempZip -UseBasicParsing
    Write-Host "[*] Extracting..."
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
    $panelSrc = Find-PanelRoot -SearchRoot $tempExtract
    Write-Host "[*] Installing to $InstallDir"
    Sync-PanelFiles -SourceDir $panelSrc -TargetDir $InstallDir
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
}

$cfg = Get-Config -RepoOverride $GitHubRepo -BranchOverride $GitHubBranch
$InstallDir = Join-Path $env:LOCALAPPDATA $cfg.install_folder

if ($KeyAuthDownloadUrl) {
    Write-Host "[*] KeyAuth update..."
    Install-FromZip -ZipUrl $KeyAuthDownloadUrl -InstallDir $InstallDir
} else {
    $repo = $cfg.github_repo
    if ($repo -match 'YOUR_GITHUB') { throw "github_repo not configured" }
    $zipUrl = "https://github.com/$repo/archive/refs/heads/$($cfg.github_branch).zip"
    Install-FromZip -ZipUrl $zipUrl -InstallDir $InstallDir
}

$python = Ensure-Python
Ensure-Venv -PanelDir $InstallDir -PythonExe $python | Out-Null
Write-Host "[OK] Ready at $InstallDir"

if (-not $SkipLaunch) {
    $startPs1 = Join-Path $InstallDir 'START.ps1'
    if (Test-Path $startPs1) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $startPs1
    }
}
