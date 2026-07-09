from pymem import *
from pymem.memory import read_bytes, write_bytes
from pymem.pattern import pattern_scan_all
import os
from time import sleep
from datetime import datetime
import pymem
import threading
import ctypes


def mkp(aob: str):
    if '??' in aob:
        if aob.startswith("??"):
            aob = f" {aob}"
            n = aob.replace(" ??", ".").replace(" ", "\\x")
            b = bytes(n.encode())
        else:
            n = aob.replace(" ??", ".").replace(" ", "\\x")
            b = bytes(f"\\x{n}".encode())
        del n
        return b
    else:
        m = aob.replace(" ", "\\x")
        c = bytes(f"\\x{m}".encode())
        del m
        return c
    
def RemoveRecoil():
    try:
       proc = Pymem("HD-Player")
    except:
        pass

    try:
       if proc:
        value = pattern_scan_all(proc.process_handle, mkp("7a 44 f0 48 2d e9 10 b0 8d e2 02 8b 2d ed 08 d0 4d e2 00 50 a0 e1 10 1a 08 ee 08 40 95 e5 00 00 54 e3"), return_multiple=True)
    except:
        pass
  
    

    if value :
      for addr in value :
        write_bytes(proc.process_handle, addr, bytes.fromhex("00 00"),2)


def AddRecoil():
    try:
       proc = Pymem("HD-Player")
    except:
        pass

    try:
       if proc:
        value = pattern_scan_all(proc.process_handle, mkp("00 00 f0 48 2d e9 10 b0 8d e2 02 8b 2d ed 08 d0 4d e2 00 50 a0 e1 10 1a 08 ee 08 40 95 e5 00 00 54 e3"), return_multiple=True)
    except:
        pass
  
    

    if value :
      for addr in value :
        write_bytes(proc.process_handle, addr, bytes.fromhex("7a 44"),2)



# Brutal-style Sniper Scope: same AOB and replace/restore bytes as brtualext Form2.cs
SNIPER_SCOPE_SCAN_AOB = (
    "FF FF FF FF 08 00 00 00 00 00 60 40 "
    "CD CC 8C 3F 8F C2 F5 3C CD CC CC 3D "
    "06 00 00 00 00 00 00 00 00 00 00 00 "
    "00 00 00 00 00 00 00 00 00 00 80 3F "
    "33 33 13 40 00 00 B0 3F 00 00 80 3F 01"
)
# ReapplySniperScope replace bytes (Brutal)
SNIPER_SCOPE_REPLACE_HEX = (
    "FF FF FF FF 08 00 00 00 00 00 60 40 "
    "CD CC 8C 3F 8F C2 F5 3C CD CC CC 3D "
    "06 00 00 00 00 00 19 3F 00 00 00 00 "
    "00 00 00 00 00 00 00 00 00 00 00 00"
)
# RestoreSniperScope: original bytes (first 48 bytes of scan pattern)
SNIPER_SCOPE_RESTORE_HEX = (
    "FF FF FF FF 08 00 00 00 00 00 60 40 "
    "CD CC 8C 3F 8F C2 F5 3C CD CC CC 3D "
    "06 00 00 00 00 00 00 00 00 00 00 00 "
    "00 00 00 00 00 00 00 00 00 00 80 3F "
    "33 33 13 40 00 00 B0 3F 00 00 80 3F"
)

sniperScopeAddress = []
sniperScopeActive = False
_sniperWatcherThread = None
# VK codes same as Brutal SniperAiWatching
SNIPER_TRIGGER_KEYS = (0x01, 0x02, 0x04, 0x05, 0x06, 0x45, 0x51, 0x54, 0x56)  # LButton,RButton,MButton,X1,X2,E,Q,T,V

# Brutal-style Sniper Switch (from brtualext BRUTALV1 Form2.cs)
SNIPER_SWITCH_AOB1 = (
    "3F 0A D7 A3 3D 00 00 00 00 00 00 5C 43 00 00 90 42 00 00 B4 42 "
    "96 00 00 00 00 00 00 00 00 00 00 3F 00 00 80 3E 00 00 00 00 04 "
    "00 00 00 00 00 80 3F 00 00 20 41 00 00 34 42 01 00 00 00 01 00 "
    "00 00 00 00 00 00 00 00 00 00 00 00 80 3F 0A D7 23 3F 9A 99 99 "
    "3F 00 00 80 3F 00 00 00 00 00 00 80 3F 00 00 80 3F 00 00 80 3F "
    "00 00 00 00 00 00 00 00 00 00 00 3F 00 00 00 00 00 00 00 00 00 "
    "00 00 00 00 00 80 3F 00 00 80 3F 00 00 80 3F 00 00 00 00 01 00 "
    "00 00 0A D7 23 3C CD CC CC 3D 9A 99 19 3F 1F 85 6B 3F"
)
SNIPER_SWITCH_REPLACE1 = (
    "3F 0A D7 A3 3D 00 00 00 00 00 00 5C 43 00 00 90 42 00 00 B4 42 "
    "96 00 00 00 00 00 00 00 00 00 00 3F 00 00 80 3E 00 00 00 3C 04"
)

SNIPER_SWITCH_AOB2 = (
    "B4 42 96 00 00 00 00 00 00 00 00 00 00 3F 00 00 80 3E 00 00 00 "
    "00 04 00 00 00 00 00 80 3F 00 00 20 41 00 00 34 42 01 00 00 00 "
    "01 00 00 00 00 00 00 00"
)
SNIPER_SWITCH_REPLACE2 = (
    "B4 42 96 00 00 00 00 00 00 00 00 00 00 3C 00 00 80 3C 00 00 00 "
    "00 04 00 00 00 00 00 80 3F 00 00 20 41 00 00 34 42 01 00 00 00 "
    "01 00 00 00 00 00 00 00"
)

sniperSwitchAddress1 = []
sniperSwitchAddress2 = []
original_Switch_value1 = []
original_Switch_value2 = []


def SNIPERSCOPELOAD():
    """
    Brutal style: scan AOB and cache sniper-scope addresses (same as brtualext SniperScopeDynamicPatcher).
    """
    global sniperScopeAddress

    try:
        proc = Pymem("HD-Player")
    except pymem.exception.ProcessNotFound:
        print("HD-Player not found")
        return "HD-Player not found"

    try:
        print("\033[31m[>]\033[0m Searching Sniper Scope (Brutal method)...")
        sniperScopeAddress = pattern_scan_all(
            proc.process_handle,
            mkp(SNIPER_SCOPE_SCAN_AOB),
            return_multiple=True,
        )

        if sniperScopeAddress:
            print(f"Sniper Scope addresses found: {len(sniperScopeAddress)}")
            return "Sniper Scope pattern loaded"
        else:
            print("Sniper Scope pattern not found")
            sniperScopeAddress = []
            return "Sniper Scope pattern not found"
    except Exception:
        print("Sniper Scope scan error")
        return "Sniper Scope scan error"
    finally:
        proc.close_process()


def _reapply_sniper_scope(proc):
    """Brutal ReapplySniperScope: write replace bytes to all addresses."""
    replace_bytes = bytes.fromhex(SNIPER_SCOPE_REPLACE_HEX.replace(" ", ""))
    for addr in sniperScopeAddress:
        write_bytes(proc.process_handle, addr, replace_bytes, len(replace_bytes))


def _restore_sniper_scope(proc):
    """Brutal RestoreSniperScope: write original bytes back."""
    restore_bytes = bytes.fromhex(SNIPER_SCOPE_RESTORE_HEX.replace(" ", ""))
    for addr in sniperScopeAddress:
        write_bytes(proc.process_handle, addr, restore_bytes, len(restore_bytes))


def _sniper_briler_control():
    """Brutal SniperBrilerControl: Reapply -> 48ms -> Restore (temp patch only)."""
    global sniperScopeAddress
    if not sniperScopeAddress:
        return
    try:
        proc = Pymem("HD-Player")
    except Exception:
        return
    try:
        _reapply_sniper_scope(proc)
        sleep(0.048)
        _restore_sniper_scope(proc)
    except Exception:
        pass
    finally:
        try:
            proc.close_process()
        except Exception:
            pass


def _sniper_ai_watching():
    """Brutal SniperAiWatching: on trigger key press run BrilerControl (300ms cooldown)."""
    global sniperScopeActive
    GetAsyncKeyState = ctypes.windll.user32.GetAsyncKeyState
    cooldown_until = 0.0
    while sniperScopeActive:
        sleep(0.02)
        if not sniperScopeAddress:
            continue
        now = datetime.now().timestamp()
        if now < cooldown_until:
            continue
        pressed = any((GetAsyncKeyState(vk) & 0x8000) for vk in SNIPER_TRIGGER_KEYS)
        if pressed:
            _sniper_briler_control()
            cooldown_until = now + 0.3


def ACTIVATELOADEDSCOPE():
    """
    Brutal method: start watcher thread. On trigger key (LButton, V, T, E, Q, MButton, X1, X2)
    temporarily apply patch for 48ms then restore. No permanent patch = no fake damage.
    """
    global sniperScopeActive, sniperScopeAddress, _sniperWatcherThread

    if not sniperScopeAddress:
        SNIPERSCOPELOAD()
        if not sniperScopeAddress:
            return "Sniper Scope pattern not found"

    if sniperScopeActive:
        return "Sniper Scope ON"

    try:
        sniperScopeActive = True
        _sniperWatcherThread = threading.Thread(target=_sniper_ai_watching, daemon=True)
        _sniperWatcherThread.start()
        return "Sniper Scope ON (Brutal method)"
    except Exception:
        sniperScopeActive = False
        return "Sniper Scope apply error"


def REMOVELOADEDSCOPE():
    """Stop Brutal watcher and ensure memory is restored."""
    global sniperScopeActive, sniperScopeAddress

    sniperScopeActive = False
    if _sniperWatcherThread and _sniperWatcherThread.is_alive():
        _sniperWatcherThread.join(timeout=0.5)

    if not sniperScopeAddress:
        return "Sniper Scope was not enabled"

    try:
        proc = Pymem("HD-Player")
    except pymem.exception.ProcessNotFound:
        return "Sniper Scope OFF"

    try:
        _restore_sniper_scope(proc)
        return "Sniper Scope OFF"
    except Exception:
        return "Sniper Scope restore error"
    finally:
        proc.close_process()



def SNIPERSWITCHLOAD():
    """
    BrutalExt-style Sniper Switch: scan both AoB patterns and cache addresses.
    """
    global sniperSwitchAddress1, sniperSwitchAddress2

    try:
        proc = Pymem("HD-Player")
    except pymem.exception.ProcessNotFound:
        print("HD-Player not found for Sniper Switch")
        return "HD-Player not found"

    try:
        print("\033[31m[>]\033[0m Searching Sniper Switch (BrutalExt)...")

        sniperSwitchAddress1 = pattern_scan_all(
            proc.process_handle,
            mkp(SNIPER_SWITCH_AOB1),
            return_multiple=True,
        ) or []

        sniperSwitchAddress2 = pattern_scan_all(
            proc.process_handle,
            mkp(SNIPER_SWITCH_AOB2),
            return_multiple=True,
        ) or []

        total = len(sniperSwitchAddress1) + len(sniperSwitchAddress2)
        print(f"Sniper Switch addresses found: {total}")

        if total == 0:
            return "Sniper Switch pattern not found"
        return f"Sniper Switch pattern loaded ({total} addresses)"
    except Exception as e:
        print(f"Sniper Switch scan error: {e}")
        return "Sniper Switch scan error"
    finally:
        try:
            proc.close_process()
        except Exception:
            pass


def ACTIVATELOADEDSWITCH():
    """
    BrutalExt-style Sniper Switch ON:
    - Uses two AoB patterns
    - Writes the same replacement bytes BrutalExt uses
    - Caches original bytes so we can restore on OFF.
    """
    global original_Switch_value1, original_Switch_value2

    if not sniperSwitchAddress1 and not sniperSwitchAddress2:
        # Auto-load if not already loaded
        msg = SNIPERSWITCHLOAD()
        if "loaded" not in str(msg):
            return msg

    try:
        proc = Pymem("HD-Player")
    except pymem.exception.ProcessNotFound:
        print("HD-Player not found for Sniper Switch ON")
        return "HD-Player not found"

    try:
        replace1 = bytes.fromhex(SNIPER_SWITCH_REPLACE1.replace(" ", ""))
        replace2 = bytes.fromhex(SNIPER_SWITCH_REPLACE2.replace(" ", ""))

        len1 = len(replace1)
        len2 = len(replace2)

        original_Switch_value1 = []
        original_Switch_value2 = []

        for addr in sniperSwitchAddress1:
            current = read_bytes(proc.process_handle, addr, len1)
            original_Switch_value1.append((addr, current))
            write_bytes(proc.process_handle, addr, replace1, len1)

        for addr in sniperSwitchAddress2:
            current = read_bytes(proc.process_handle, addr, len2)
            original_Switch_value2.append((addr, current))
            write_bytes(proc.process_handle, addr, replace2, len2)

        print("Sniper Switch Activated (BrutalExt method)")
        return "Sniper Switch Activated"
    except Exception as e:
        print(f"Sniper Switch apply error: {e}")
        return "Sniper Switch apply error"
    finally:
        try:
            proc.close_process()
        except Exception:
            pass


def REMOVELOADEDSWITCH():
    """
    BrutalExt-style Sniper Switch OFF: restore original bytes for both patterns.
    """
    global original_Switch_value1, original_Switch_value2

    if not original_Switch_value1 and not original_Switch_value2:
        return "Sniper Switch was not enabled"

    try:
        proc = Pymem("HD-Player")
    except pymem.exception.ProcessNotFound:
        print("HD-Player not found for Sniper Switch OFF")
        return "Sniper Switch OFF"

    try:
        for addr, original in original_Switch_value1:
            write_bytes(proc.process_handle, addr, original, len(original))

        for addr, original in original_Switch_value2:
            write_bytes(proc.process_handle, addr, original, len(original))

        print("Sniper Switch Disabled (BrutalExt method)")
        return "Sniper Switch Disabled"
    except Exception as e:
        print(f"Sniper Switch restore error: {e}")
        return "Sniper Switch restore error"
    finally:
        try:
            proc.close_process()
        except Exception:
            pass