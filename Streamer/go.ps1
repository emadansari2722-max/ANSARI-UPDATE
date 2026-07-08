# Ansari Cheats — GitHub se DLL download + inject (sirf 4KB file)
$ErrorActionPreference = 'Stop'
$dllUrl = 'https://github.com/emadansari2722-max/ANSARI-UPDATE/raw/refs/heads/main/Streamer/Streamer.dll'
$work = "$env:APPDATA\AnsariCheats\launcher"
$dll = Join-Path $work 'payload.dll'
$emuNames = @('HD-Player', 'MSIAppPlayer', 'BlueStacks', 'Nox', 'LdVBoxHeadless')

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Admin PowerShell chahiye' -ForegroundColor Red; exit 1
}

New-Item -ItemType Directory -Force -Path $work | Out-Null
Write-Host 'DLL download...' -ForegroundColor Cyan
Invoke-WebRequest -Uri $dllUrl -OutFile $dll -UseBasicParsing -TimeoutSec 300
if (-not (Test-Path $dll) -or (Get-Item $dll).Length -lt 10000) { throw 'DLL download fail' }

Write-Host 'Emulator kholo...' -ForegroundColor Yellow
$emu = $null
for ($i = 0; $i -lt 120; $i++) {
    foreach ($n in $emuNames) { $emu = Get-Process -Name $n -EA SilentlyContinue | Select-Object -First 1; if ($emu) { break } }
    if ($emu) { break }; Start-Sleep 2
}
if (-not $emu) { throw 'Emulator nahi mila' }

if (-not ('BlazeInject.Injector' -as [type])) {
Add-Type 'using System;using System.Runtime.InteropServices;using System.Text;namespace BlazeInject{public static class Injector{const uint P=0x1F0FFF,C=0x1000,R=0x2000,W=0x04;[DllImport("kernel32")]static extern IntPtr OpenProcess(uint a,bool b,int c);[DllImport("kernel32")]static extern IntPtr VirtualAllocEx(IntPtr h,IntPtr a,uint s,uint t,uint p);[DllImport("kernel32")]static extern bool WriteProcessMemory(IntPtr h,IntPtr a,byte[] b,uint s,out UIntPtr w);[DllImport("kernel32")]static extern IntPtr CreateRemoteThread(IntPtr h,IntPtr a,uint s,IntPtr st,IntPtr p,uint f,out IntPtr t);[DllImport("kernel32",CharSet=CharSet.Ansi)]static extern IntPtr GetProcAddress(IntPtr m,string n);[DllImport("kernel32",CharSet=CharSet.Unicode)]static extern IntPtr GetModuleHandleW(string n);[DllImport("kernel32")]static extern uint WaitForSingleObject(IntPtr h,uint ms);[DllImport("kernel32")]static extern bool CloseHandle(IntPtr h);public static bool Inject(int pid,string path){if(string.IsNullOrWhiteSpace(path)||!System.IO.File.Exists(path))return false;IntPtr hp=OpenProcess(P,false,pid);if(hp==IntPtr.Zero)return false;byte[] b=Encoding.Unicode.GetBytes(path+"\0");IntPtr al=VirtualAllocEx(hp,IntPtr.Zero,(uint)b.Length,C|R,W);if(al==IntPtr.Zero){CloseHandle(hp);return false;}UIntPtr wr;if(!WriteProcessMemory(hp,al,b,(uint)b.Length,out wr)){CloseHandle(hp);return false;}IntPtr ll=GetProcAddress(GetModuleHandleW("kernel32.dll"),"LoadLibraryW");IntPtr th=CreateRemoteThread(hp,IntPtr.Zero,0,ll,al,0,out _);if(th==IntPtr.Zero){CloseHandle(hp);return false;}WaitForSingleObject(th,15000);CloseHandle(th);CloseHandle(hp);return true;}}'
}

$full = (Resolve-Path $dll).Path
Write-Host "Inject pid=$($emu.Id)..." -ForegroundColor Cyan
if (-not [BlazeInject.Injector]::Inject([int]$emu.Id, $full)) { throw 'Inject fail' }
Write-Host 'DONE — Inject ho gaya!' -ForegroundColor Green
