import glob
import os
import subprocess
import psutil
from pymem import *

def block_internet():
    commands = [
        'netsh advfirewall firewall add rule name="FF Block In1" dir=in action=block program="%ProgramFiles%\\BlueStacks_nxt\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In1" dir=out action=block program="%ProgramFiles%\\BlueStacks_nxt\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In2" dir=in action=block program="%ProgramFiles%\\BlueStacks\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In2" dir=out action=block program="%ProgramFiles%\\BlueStacks\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In3" dir=in action=block program="%ProgramFiles%\\BlueStacks_msi2\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In3" dir=out action=block program="%ProgramFiles%\\BlueStacks_msi2\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In6" dir=in action=block program="%ProgramFiles%\\BlueStacks_msi5\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In6" dir=out action=block program="%ProgramFiles%\\BlueStacks_msi5\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In4" dir=in action=block program="%ProgramData%\\BlueStacks_msi5\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In4" dir=out action=block program="%ProgramData%\\BlueStacks_msi5\\HD-Player.exe"',
        'netsh advfirewall firewall add rule name="FF Block In5" dir=in action=block program="%ProgramFiles(x86)%\\SmartGaGa\\ProjectTitan\\Engine\\ProjectTitan.exe"',
        'netsh advfirewall firewall add rule name="FF Block In5" dir=out action=block program="%ProgramFiles(x86)%\\SmartGaGa\\ProjectTitan\\Engine\\ProjectTitan.exe"',
    ]

    for command in commands:
        subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    return('Emulator Network Blocked.')

def unblock_internet():
    commands = [
        'netsh advfirewall firewall delete rule name="FF Block In1" program="%ProgramFiles%\\BlueStacks_nxt\\HD-Player.exe"',
        'netsh advfirewall firewall delete rule name="FF Block In2" program="%ProgramFiles%\\BlueStacks\\HD-Player.exe"',
        'netsh advfirewall firewall delete rule name="FF Block In3" program="%ProgramFiles%\\BlueStacks_msi2\\HD-Player.exe"',
        'netsh advfirewall firewall delete rule name="FF Block In6" program="%ProgramFiles%\\BlueStacks_msi5\\HD-Player.exe"',
        'netsh advfirewall firewall delete rule name="FF Block In4" program="%ProgramData%\\BlueStacks_msi5\\HD-Player.exe"',
        'netsh advfirewall firewall delete rule name="FF Block In5" program="%ProgramFiles(x86)%\\SmartGaGa\\ProjectTitan\\Engine\\ProjectTitan.exe"',
    ]

    for command in commands:
        subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    return('Emulator Network Unblocked.')

def run_command(command):
    """Helper function to run a system command."""
    try:
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        
def full_cleanup():
    commands = [
        "del /s /f /q %windir%\\temp\\*.*",
        "rd /s /q %windir%\\temp",
        "md %windir%\\temp",
        "del /s /f /q %windir%\\Prefetch\\*.*",
        "rd /s /q %windir%\\Prefetch",
        "md %windir%\\Prefetch",
        "del /s /f /q %windir%\\system32\\dllcache\\*.*",
        "rd /s /q %windir%\\system32\\dllcache",
        "md %windir%\\system32\\dllcache",
        "del /s /f /q \"%SystemDrive%\\Temp\\*.*\"",
        "rd /s /q \"%SystemDrive%\\Temp\"",
        "md \"%SystemDrive%\\Temp\"",
        "del /s /f /q %temp%\\*.*",
        "rd /s /q %temp%",
        "md %temp%",
        "del /s /f /q \"%USERPROFILE%\\Local Settings\\History\\*.*\"",
        "rd /s /q \"%USERPROFILE%\\Local Settings\\History\"",
        "md \"%USERPROFILE%\\Local Settings\\History\"",
        "del /s /f /q \"%USERPROFILE%\\Local Settings\\Temporary Internet Files\\*.*\"",
        "rd /s /q \"%USERPROFILE%\\Local Settings\\Temporary Internet Files\"",
        "md \"%USERPROFILE%\\Local Settings\\Temporary Internet Files\"",
        "del /s /f /q \"%USERPROFILE%\\Local Settings\\Temp\\*.*\"",
        "rd /s /q \"%USERPROFILE%\\Local Settings\\Temp\"",
        "md \"%USERPROFILE%\\Local Settings\\Temp\"",
        "del /s /f /q \"%USERPROFILE%\\Recent\\*.*\"",
        "rd /s /q \"%USERPROFILE%\\Recent\"",
        "md \"%USERPROFILE%\\Recent\"",
        "del /s /f /q \"%USERPROFILE%\\Cookies\\*.*\"",
        "rd /s /q \"%USERPROFILE%\\Cookies\"",
        "md \"%USERPROFILE%\\Cookies\"",
        "cls"
    ]
    for command in commands:
        run_command(command)
    try:
        result = subprocess.run("bcdedit", capture_output=True, text=True, shell=True)
        admin_check = result.stdout.splitlines()
        admin_status = any("Access" in line for line in admin_check)

        if not admin_status:
            print("You must run this script as an Administrator!")
            return
        
    except Exception as e:
        print(f"Error checking admin status: {e}")
        return
    try:
        event_logs = subprocess.run("wevtutil.exe el", capture_output=True, text=True, shell=True)
        for log in event_logs.stdout.splitlines():
            subprocess.run(f"wevtutil.exe cl {log}", shell=True)
        print("\nEvent Logs have been cleared!")
    except Exception as e:
        print(f"Error clearing event logs: {e}")
    registry_keys = [
        r"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
        r"HKEY_LOCAL_MACHINE\SOFTWARE\Clients\StartMenuInternet",
        r"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU\dll",
        r"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts.dll\OpenWithList",
        r"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU",
        r"HKEY_USERS\%usersid%\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU",
        r"HKEY_USERS\%usersid%\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU\dll"
    ]
    appdata_path = os.getenv("APPDATA")
    files_to_delete = [
        os.path.join(appdata_path, "Microsoft\\Windows\\Recent\\*.*"),
        os.path.join(appdata_path, "Microsoft\\Windows\\Recent\\CustomDestinations\\*.*"),
        os.path.join(appdata_path, "Microsoft\\Windows\\Recent\\AutomaticDestinations\\*.*"),
        os.path.join(os.getenv("SYSTEMROOT"), "appcompat\\Programs\\*.txt"),
        os.path.join(os.getenv("SYSTEMROOT"), "appcompat\\Programs\\*.xml"),
        os.path.join(os.getenv("SYSTEMROOT"), "Prefetch\\*.*"),
        os.path.join(os.getenv("SYSTEMROOT"), "Minidump\\*.*")
    ]
    for key in registry_keys:
        try:
            subprocess.run(f'reg delete "{key}" /f', check=True)
        except subprocess.CalledProcessError:
            print(f"Failed to delete registry key: {key}")
    for file_path in files_to_delete:
        try:
            for file in glob.glob(file_path):
                os.remove(file)
        except Exception as e:
            print(f"Failed to delete file: {file_path} - {e}")
            return 'Failed BYPASS'

    return('PC BYPASS SUCCESSFUL')

def disconnect():
    processes_terminated = 0 
    for process in psutil.process_iter(['name']):
        if process.info['name'] == 'NisSrv.exe':
            process.terminate()
            process.wait() 
            processes_terminated += 1
    if processes_terminated > 0:
        print(f'{processes_terminated} instances of NVIDIA Container.exe terminated. You need to run the script again.')
    else:
        print("NVIDIA Container.exe is not running.")