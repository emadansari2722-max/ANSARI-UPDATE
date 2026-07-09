from pymem import *
from pymem.memory import read_bytes, write_bytes
from pymem.pattern import pattern_scan_all
import os
import sys
from time import sleep
from datetime import datetime

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        # Fallback to the directory where this script resides
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


def box3d():
    process_name = "HD-Player"

    try:

        temp_dll_path = resource_path('BOX.dll')

        dll_path_bytes = bytes(temp_dll_path.encode('UTF-8'))

        open_process = Pymem(process_name)

        process_name.inject_dll(open_process.process_handle, dll_path_bytes)
        print("Chams Box Injected DLL Successfully!") 

    except pymem.exception.ProcessNotFound:
        print("Task Manager not found!")
    except Exception as e:
        print(f"Error: {e}")

def chamsmenu():
    process_name = "HD-Player.exe"

    try:

        temp_dll_path = resource_path('charms_menu.dll')

        dll_path_bytes = bytes(temp_dll_path.encode('UTF-8'))

        open_process = Pymem(process_name)

        process_name.inject_dll(open_process.process_handle, dll_path_bytes)
        print("Chams Blue Injected DLL Successfully!") 

    except pymem.exception.ProcessNotFound:
        print("Task Manager not found!")
    except Exception as e:
        print(f"Error: {e}")

def chams3d():
    process_name = "HD-Player.exe"

    try:

        temp_dll_path = resource_path('wallfixedchams.dll')

        dll_path_bytes = bytes(temp_dll_path.encode('UTF-8'))

        open_process = Pymem(process_name)

        process_name.inject_dll(open_process.process_handle, dll_path_bytes)
        print("Chams 3D Injected DLL Successfully!") 

    except pymem.exception.ProcessNotFound:
        print("Task Manager not found!")
    except Exception as e:
        print(f"Error: {e}")
