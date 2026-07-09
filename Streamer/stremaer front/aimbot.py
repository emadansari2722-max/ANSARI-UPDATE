import threading
import time
import ctypes
from pynput import mouse, keyboard
import psutil
import win32gui
import win32process

enabled = False
dragging = False
settings = {
    "delay": 0,
    "speed": 10,
    "key": "left"  # default
}

PUL = ctypes.POINTER(ctypes.c_ulong)

class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", ctypes.c_long),
                ("dy", ctypes.c_long),
                ("mouseData", ctypes.c_ulong),
                ("dwFlags", ctypes.c_ulong),
                ("time", ctypes.c_ulong),
                ("dwExtraInfo", PUL)]

class INPUT(ctypes.Structure):
    _fields_ = [("type", ctypes.c_ulong),
                ("mi", MOUSEINPUT)]

def move_mouse_raw(dx, dy):
    extra = ctypes.c_ulong(0)
    ii = INPUT(type=0, mi=MOUSEINPUT(dx, dy, 0, 0x0001, 0, ctypes.pointer(extra)))
    ctypes.windll.user32.SendInput(1, ctypes.pointer(ii), ctypes.sizeof(ii))

def is_hdplayer_in_focus():
    try:
        hwnd = win32gui.GetForegroundWindow()
        tid, pid = win32process.GetWindowThreadProcessId(hwnd)
        proc = psutil.Process(pid)
        return proc.name().lower() == "hd-player.exe"
    except Exception:
        return False

def set_autonomic_settings(delay, speed, key):
    global settings
    settings = {"delay": delay, "speed": speed, "key": key}
    print("Settings updated:", settings)

def _drag_loop():
    global dragging
    while True:
        if enabled and dragging and is_hdplayer_in_focus():
            time.sleep(settings["delay"])
            while dragging and enabled and is_hdplayer_in_focus():
                move_mouse_raw(0, -settings["speed"])
                time.sleep(0.01)
        time.sleep(0.05)

def _on_click(x, y, button, pressed):
    global dragging
    if settings["key"] == "left" and button == mouse.Button.left:
        dragging = pressed if enabled else False
    elif settings["key"] == "right" and button == mouse.Button.right:
        dragging = pressed if enabled else False

def _on_key_press(key):
    global dragging
    try:
        if hasattr(key, 'char'):
            if settings["key"] == key.char:
                dragging = True if enabled else False
    except:
        pass

def _on_key_release(key):
    global dragging
    try:
        if hasattr(key, 'char'):
            if settings["key"] == key.char:
                dragging = False
    except:
        pass

_mouse_listener_started = False
_drag_thread_started = False

def _ensure_threads_started():
    global _mouse_listener_started, _drag_thread_started
    if not _mouse_listener_started:
        mouse.Listener(on_click=_on_click).start()
        keyboard.Listener(on_press=_on_key_press, on_release=_on_key_release).start()
        _mouse_listener_started = True
    if not _drag_thread_started:
        threading.Thread(target=_drag_loop, daemon=True).start()
        _drag_thread_started = True

def aimbotv2on():
    global enabled
    enabled = True
    _ensure_threads_started()

def aimbotv2off():
    global enabled, dragging
    enabled = False
    dragging = False
