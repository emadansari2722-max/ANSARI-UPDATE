import os
import sys
import pymem
import time

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        # Fallback to the directory where this script resides
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

def inject_dll_from_path(process, dll_path):
    try:
        # Ensure DLL path exists
        if not os.path.exists(dll_path):
            raise FileNotFoundError(f"DLL file not found: {dll_path}")
        
        # Convert DLL path to bytes (UTF-8 encoding)
        dll_path_bytes = bytes(dll_path.encode('UTF-8'))
        
        # Use pymem's inject_dll method
        pymem.process.inject_dll(process.process_handle, dll_path_bytes)
        print(f"{dll_path} Injected Successfully!")
    except FileNotFoundError as e:
        print(f"File not found: {e}")
    except Exception as e:
        print(f"Failed to inject {dll_path}: {e}")

def streamesp():
    process_name = "HD-Player.exe"

    try:
        
        process = pymem.Pymem(process_name)

        # Debug: Check what's in the resource path
        try:
            base_path = sys._MEIPASS
        except:
            base_path = os.path.dirname(os.path.abspath(__file__))
        print(f"[DEBUG] Resource base path: {base_path}")
        print(f"[DEBUG] Files in base path: {os.listdir(base_path) if os.path.exists(base_path) else 'PATH NOT FOUND'}")
       
        temp_dll_path_1 = resource_path('cimgui.dll')
        temp_dll_path_2 = resource_path('AotBst.dll')

        print(f"[DEBUG] Looking for cimgui.dll at: {temp_dll_path_1}")

        inject_dll_from_path(process, temp_dll_path_1)
        time.sleep(1)  
        inject_dll_from_path(process, temp_dll_path_2)

        streamer_dll = resource_path('Streamer.dll')
        if os.path.exists(streamer_dll):
            time.sleep(1)
            inject_dll_from_path(process, streamer_dll)
        else:
            print("[WARN] Streamer.dll not found — wait for online update or place DLL in folder")

        print("Injection completed successfully.")

    except pymem.exception.ProcessNotFound:
        print("Emulator not found.")
    except Exception as e:
        print(f"Error: {e}")