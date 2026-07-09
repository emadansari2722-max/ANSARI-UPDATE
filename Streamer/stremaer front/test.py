import tkinter as tk
import threading
import time
import ctypes
from pynput import mouse

enabled = False
dragging = False
window_focused = False

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

INPUT_MOUSE = 0
MOUSEEVENTF_MOVE = 0x0001

def move_mouse_raw(dx, dy):
    extra = ctypes.c_ulong(0)
    ii = INPUT(type=INPUT_MOUSE,
               mi=MOUSEINPUT(dx=dx, dy=dy, mouseData=0,
                             dwFlags=MOUSEEVENTF_MOVE,
                             time=0,
                             dwExtraInfo=ctypes.pointer(extra)))
    ctypes.windll.user32.SendInput(1, ctypes.pointer(ii), ctypes.sizeof(ii))

def drag_thread():
    while True:
        if enabled and dragging and not window_focused:
            move_mouse_raw(0, -10) 
            time.sleep(0.01)
        else:
            time.sleep(0.05)

def on_click(x, y, button, pressed):
    global dragging
    if button == mouse.Button.left:
        if pressed and enabled and not window_focused:
            dragging = True
        else:
            dragging = False

mouse_listener = mouse.Listener(on_click=on_click)
mouse_listener.start()

def toggle():
    global enabled
    enabled = not enabled
    toggle_btn.config(text="Disable" if enabled else "Enable")

def on_focus_in(event):
    global window_focused
    window_focused = True

def on_focus_out(event):
    global window_focused
    window_focused = False

# GUI Setup
root = tk.Tk()
root.title("Auto Drag")

# 200% UI scaling (Tk uses points; scaling affects widget sizing)
root.tk.call("tk", "scaling", 2.0)

root.geometry("440x200")
root.resizable(False, False)

toggle_btn = tk.Button(root, text="Enable", font=("Arial", 28), command=toggle)
toggle_btn.pack(expand=True, fill="both", padx=20, pady=20)

root.bind("<FocusIn>", on_focus_in)
root.bind("<FocusOut>", on_focus_out)

threading.Thread(target=drag_thread, daemon=True).start()

root.mainloop()
