from flask_cors import CORS
from flask import *
from keyauth import *



def send_command_to_esp(command: str):
    pipe_path = r'\\.\pipe\esp_pipe'
    try:
        with open(pipe_path, 'w') as pipe:
            pipe.write(command + '\n')
    except FileNotFoundError:
        print("Pipe not found. Make sure the C# ESP app is running.")
    except Exception as e:
        print(f"Pipe error: {e}")

def aimbotvisible():
    send_command_to_esp("aimbotvisible")
    return "Aimbot Initialized Successfully."

def aimbotvisibleoff():
    send_command_to_esp("aimbotvisibleoff")
    return "Aimbot Turned off."
    
def silentaim():
    send_command_to_esp("silentaim")

def silentaimoff():
    send_command_to_esp("silentaimoff")

def upplayer():
    send_command_to_esp("upplayer")
    return "Up Player enabled."
    
def upplayeroff():
    send_command_to_esp("upplayeroff")
    return "Up Player disabled."

def enablefunction():
    send_command_to_esp("enablefunction")

def enablefunctionoff():
    send_command_to_esp("enablefunctionoff")

def aimbotrage():
    send_command_to_esp("aimbotrage")
    

def aimbotrageoff():
    send_command_to_esp("aimbotrageoff")

def streamermode():
    send_command_to_esp("streammode")
    return "Streamer mode enabled."

def streamermodeoff():
    send_command_to_esp("streammodeoff")
    return "Streamer mode disabled."

def drawfov():
    send_command_to_esp("drawfov")
    return "Fov Drawn on Screen."

def drawfovoff():
    send_command_to_esp("drawfovoff")
    return "Fov Drawn off from Screen."

def on_fov_change(value):
    send_command_to_esp(f"aimfov:{value:.1f}")

def set_silentaim_mode(mode_index):
    send_command_to_esp(f"silentaim_mode:{mode_index}")
    return f"Silent Aim mode set to: {mode_index}"

def espline():
    send_command_to_esp("esplineonn")
    return "Esp line On."

def esplineoff():
    send_command_to_esp("esplineoff")
    return "Esp line Off."

def espboxon():
    send_command_to_esp("espboxon")
    return "Esp Box On."

def espboxoff():
    send_command_to_esp("espboxoff")
    return "Esp Box Off."

def espname():
    send_command_to_esp("espname")
    return "Esp Name On."

def espnameoff():
    send_command_to_esp("espnameoff")
    return "Esp Name Off."

def esphealth():
    send_command_to_esp("esphealth")
    return "Esp Health On."

def esphealthoff():
    send_command_to_esp("esphealthoff")
    return "Esp Health Off."

def espskeleton():
    send_command_to_esp("espskeleton")
    return "Esp Skeleton On."

def espskeletonoff():
    send_command_to_esp("espskeletonoff")
    return "Esp Skeleton Off."

def espaimtrack():
    send_command_to_esp("espaimtrack")
    return "Esp Aim Track On."

def espaimtrackoff():
    send_command_to_esp("espaimtrackoff")
    return "Esp Aim Track Off."

def norecoil():
    send_command_to_esp("norecoil")
    return "Recoil mode set to 0."

def norecoiloff():
    send_command_to_esp("norecoiloff")
    return "Recoil mode set to normal."

def telekil():
    send_command_to_esp("telekil")
    return "Tele Kill enabled."

def telekiloff():
    send_command_to_esp("telekiloff")
    return "Tele Kill disabled."