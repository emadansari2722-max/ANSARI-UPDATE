from flask import *
import threading
import keyboard
from datetime import datetime

import sys
import time
import platform
import os
import hashlib
from time import sleep
from datetime import datetime
# from aob import *


from pymem import *
from pymem.memory import read_bytes, write_bytes
from pymem.pattern import pattern_scan_all
import os


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


    

def HEADLOAD():
    try:

        proc = Pymem("HD-Player")
    except pymem.exception.ProcessNotFound:
        return

    try:
        if proc:
            print("Scanning..")
            global aimbot_addresses
            entity_pattern = mkp("FF FF ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 00 00 ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 00 00 ?? ?? ?? ?? ?? ?? ?? ?? 00 00 A5 43")
            aimbot_addresses = pattern_scan_all(proc.process_handle, entity_pattern, return_multiple=True)

            if aimbot_addresses:
                print("Addresses found")
                
            else:
                print("Failed")
    
    except:
        print("")
    finally:
        if proc:
            proc.close_process()
    return "Fitur Berhasil Di Load"
    


def HEADON():
    try:
        proc = Pymem("HD-Player")
    
        if proc:
            global original_value
            global aimbot_addresses
            original_value = []
            for current_entity in aimbot_addresses:
                original_value.append((current_entity, read_bytes(proc.process_handle, current_entity + 0xAA, 4)))
                # Read the value at current_entity + 0x60
                # Read the value at current_entity + 0x2C
                value_bytes = read_bytes(proc.process_handle, current_entity +  0xA6, 4) 
                
                # Write the value to current_entity + 0x5C
                # Write the value to current_entity + 0x28
                write_bytes(proc.process_handle, current_entity + 0xAA, value_bytes, len(value_bytes))
    except pymem.exception.ProcessNotFound:
        print("")
        return
    finally:
        if proc:
            proc.close_process()
           
    return "AIMBOT HEAD ON"

def HEADOFF():
    try:
        # Open the process
        proc = Pymem("HD-Player")
        
        if original_value:
         
            for i in original_value:
                # Write the value to current_entity + 0x5C
                # Write the value to current_entity + 0x28
                write_bytes(proc.process_handle, i[0] + 0xAA, i[1], len(i[1]))
    except pymem.exception.ProcessNotFound:
        print("")
        return
    finally:
        if proc:
            proc.close_process()
    return "AIMBOT HEAD OFF"


def RIGHTSHOULDERON():
    try:
        proc = Pymem("HD-Player")
    
        if proc:
            global original_value
            original_value = []
            for current_entity in aimbot_addresses:
                original_value.append((current_entity, read_bytes(proc.process_handle, current_entity + 0x9E, 4)))
                # Read the value at current_entity + 0x60
                # Read the value at current_entity + 0x2C
                value_bytes = read_bytes(proc.process_handle, current_entity + 0xCE, 4)
                
                # Write the value to current_entity + 0x5C
                # Write the value to current_entity + 0x28
                write_bytes(proc.process_handle, current_entity + 0x9E, value_bytes, len(value_bytes))    
    except pymem.exception.ProcessNotFound:
        print("")
        return
    finally:
        if proc:
            proc.close_process()
           
    return "AIMBOT DRAG ON"

def RIGHTSHOULDEROFF():
    try:
        proc = Pymem("HD-Player")
        
        if original_value: 
         
            for i in original_value:
                # Write the value to current_entity + 0x5C
                # Write the value to current_entity + 0x28
                write_bytes(proc.process_handle, i[0] + 0x9E, i[1], len(i[1]))
    except pymem.exception.ProcessNotFound:
        print("")
        return
    finally:
        if proc:
            proc.close_process()
    return "AIMBOT DRAG OFF"


def LEFTSHOULDERON():
    try:

        proc = Pymem("HD-Player")
    
        if proc:
            global original_value
            original_value = []
            for current_entity in aimbot_addresses:
                original_value.append((current_entity, read_bytes(proc.process_handle, current_entity + 0x9E, 4)))
                # Read the value at current_entity + 0x60
                # Read the value at current_entity + 0x2C
                value_bytes = read_bytes(proc.process_handle, current_entity + 0xD2, 4) 
                
                # Write the value to current_entity + 0x5C
                # Write the value to current_entity + 0x28
                write_bytes(proc.process_handle, current_entity + 0x9E, value_bytes, len(value_bytes))    
    except pymem.exception.ProcessNotFound:
        print("")
        return
    finally:
        if proc:
            proc.close_process()
           
    return "AIMBOT DRAG ON"

def LEFTSHOULDEROFF():
    try:

        proc = Pymem("HD-Player")
        
        if original_value:
         
            for i in original_value:
                # Write the value to current_entity + 0x5C
                # Write the value to current_entity + 0x28
                write_bytes(proc.process_handle, i[0] + 0x9E, i[1], len(i[1]))
    except pymem.exception.ProcessNotFound:
        print("")
        return
    finally:
        if proc:
            proc.close_process()
    return "AIMBOT DRAG OFF"






def clear():
    if platform.system() == 'Windows':
        os.system('cls & title Python Example')
    elif platform.system() == 'Linux':
        os.system('clear')
        sys.stdout.write("\x1b]0;Python Example\x07")
    # elif platform.system() == 'Darwin':
    #     os.system("clear && printf '\e[3J'")
    #     os.system('''echo - n - e "\033]0;Python Example\007"''')

def getchecksum():
    md5_hash = hashlib.md5()
    file = open(''.join(sys.argv), "rb")
    md5_hash.update(file.read())
    digest = md5_hash.hexdigest()
    return digest

# if sys.platform == "win32":
#     ctypes.windll.user32.ShowWindow(ctypes.windll.kernel32.GetConsoleWindow(), 0)

# def taskmanagerloop():
#     while True:
#         taskmanager()
#         print("Taskmanager is running...")
#         time.sleep(2)  # Wait for 2 seconds

# def run_taskmanager():
#     # Running taskmanagerloop in a separate thread
#     task_thread = threading.Thread(target=taskmanagerloop)
#     task_thread.daemon = True  # Allows thread to exit when the main program exits
#     task_thread.start()