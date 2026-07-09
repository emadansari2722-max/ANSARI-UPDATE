from flask import Flask, request, redirect, url_for, session, jsonify, send_file, send_from_directory
import hashlib
import sys
import os
import psutil
import time
import threading
from keyauth import api
import winreg
from MirrorMem import *
import ctypes
from internal import *
from injector import *
from aimbot import *
import io
import contextlib
import webbrowser
import socket
from detectionbypass import *
from online_update import check_and_update_streamer_dll


app = Flask(__name__)
app.secret_key = '703822238'

def _auto_enable_streamer_mode(retries: int = 10, delay_s: float = 0.75):
    # Best-effort: pipe might not be up yet.
    for _ in range(max(1, retries)):
        try:
            streamermode()
        except Exception:
            pass
        time.sleep(max(0.0, delay_s))

def getchecksum():
    md5_hash = hashlib.md5()
    with open(''.join(sys.argv), "rb") as file:
        md5_hash.update(file.read())
    return md5_hash.hexdigest()


keyauthapp = api(
    name="streamer",
    ownerid="DZ9nqQ3a5T",
    secret="7f7875a68a16e769334512701d309315b3d57d7faa47bed177504c800863630f",
    version="2.0",
    hash_to_check=getchecksum()
)

def _run_startup_updates():
    try:
        check_and_update_streamer_dll(keyauthapp)
    except Exception as e:
        print(f"[update] {e}")

threading.Thread(target=_run_startup_updates, daemon=True).start()

if sys.platform == "win32":
  ctypes.windll.user32.ShowWindow(ctypes.windll.kernel32.GetConsoleWindow(), 0)


def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        # Fallback to the directory where this script resides so resources
        # are resolved correctly when running from source.
        base_path = os.path.dirname(os.path.abspath(__file__))

    return os.path.join(base_path, relative_path)

@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('Username')
        password = request.form.get('Password')

        try:
            response = keyauthapp.login(username, password)
            session['logged_in'] = True
            session['Username'] = keyauthapp.user_data.username
            session['expiry'] = keyauthapp.user_data.expires
            return redirect(url_for('dashboard'))
        except Exception as e:
            return f"<h3>Login failed: {str(e)}</h3><a href='/'>Back to login</a>"

    return send_file(resource_path('login.html'))


def add_to_startup():
    file_path = sys.executable 
    reg_key = r"Software\Microsoft\Windows\CurrentVersion\Run"
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, reg_key, 0, winreg.KEY_SET_VALUE) as key:
            winreg.SetValueEx(key, "AnsariCheatsApp", 0, winreg.REG_SZ, file_path)
    except Exception as e:
        print(f"Startup registration failed: {e}")


@app.route('/index.html')
def dashboard():
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    # Ensure Streamer Mode is ON once user reaches dashboard.
    try:
        streamermode()
    except Exception:
        pass
    return send_file(resource_path('index.html'))


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# Serve static files (MUST BE BEFORE OTHER ROUTES)
@app.route('/bg%20main/<path:filename>')
@app.route('/bg main/<path:filename>')
def serve_bg_image(filename):
    try:
        file_path = resource_path(f'bg main/{filename}')
        return send_file(file_path, mimetype='image/jpeg')
    except Exception as e:
        print(f"BG Image error: {str(e)}")
        return f"File not found: {str(e)}", 404

@app.route('/video%20sound/<path:filename>')
@app.route('/video sound/<path:filename>')  
def serve_media(filename):
    try:
        file_path = resource_path(f'video sound/{filename}')
        if filename.endswith('.mp4'):
            mimetype = 'video/mp4'
        elif filename.endswith('.mp3'):
            mimetype = 'audio/mpeg'
        else:
            mimetype = 'application/octet-stream'
        return send_file(file_path, mimetype=mimetype)
    except Exception as e:
        print(f"Media error: {str(e)}")
        return f"File not found: {str(e)}", 404

@app.route('/devimage/<path:filename>')
def serve_devimage(filename):
    try:
        file_path = resource_path(f'devimage/{filename}')
        if filename.endswith('.jpeg') or filename.endswith('.jpg'):
            mimetype = 'image/jpeg'
        elif filename.endswith('.png'):
            mimetype = 'image/png'
        else:
            mimetype = 'application/octet-stream'
        return send_file(file_path, mimetype=mimetype)
    except Exception as e:
        print(f"DevImage error: {str(e)}")
        return f"File not found: {str(e)}", 404

@app.route('/devimage-hex/<filename>')
def serve_devimage_hex(filename):
    try:
        file_path = resource_path(f'devimage/{filename}')
        with open(file_path, 'r') as f:
            content = f.read()
        return jsonify({'hexData': content})
    except Exception as e:
        print(f"DevImage Hex error: {str(e)}")
        return jsonify({'error': str(e)}), 404

@app.route("/save_autonomic_settings", methods=["POST"])
def save_autonomic_settings():
    data = request.get_json()
    delay = int(data.get("delay", 0))
    speed = int(data.get("speed", 10))
    key = data.get("key", "left")
    
    print(f"Received Autonomic Settings: delay={delay}, speed={speed}, key={key}")
    set_autonomic_settings(delay, speed, key)
    return "Settings updated", 200

@app.route('/execute', methods=['POST'])
def execute_command():
    data = request.get_json()
    command = data.get('command')

    if not command:
        return jsonify({"output": "No command received."}), 400

    with io.StringIO() as buf, contextlib.redirect_stdout(buf):
        response_message = process_command(command)
        printed_output = buf.getvalue()


    combined_output = printed_output + (response_message or "")
    return jsonify({"output": combined_output})


@app.route('/status')
def check_status():
    process_name = "HD-Player.exe"
    for proc in psutil.process_iter(['name']):
        if proc.info['name'] == process_name:
            return jsonify({"status": "online"})
    return jsonify({"status": "offline"})




def is_hd_player_running():
    for proc in psutil.process_iter(['name']):
        if proc.info['name'] and proc.info['name'].lower() == 'hd-player.exe':
            return True
    return False

def simulate_ping():
    return round(time.time() * 1000) % 150 + 50

@app.route('/check-hd-player-status')
def check_hd_player_status():
    running = is_hd_player_running()
    return jsonify({
        "isRunning": running,
        "ping": simulate_ping() if running else None
    })




def process_command(command):
    
    match command:
        case "aimbotscan":
            HEADLOAD()
            return "Enemies successfully scanned."
        case "aimbotvisible":
            aimbotvisible()
            return "Aimbot version-2 Enabled."
        case "bypasspc":
            full_cleanup()
            return "Pc logs in controll. All logs cleaned"
        case "aimbotvisibleoff":                            
            aimbotvisibleoff()
            return "Aimbot version-2 Disabled."
        case "aimbotenable":
            HEADON()
            return "Aim : Neck Enabled"
        case "aimbotdisable":
            HEADOFF()
            return "Aim : Neck Disabled"
        case "leftShoulderOn":  
            LEFTSHOULDERON()
            return "Aim : Left-shoulder Enabled"
        case "leftShoulderOff":
            LEFTSHOULDEROFF()
            return "Aim : Left-shoulder Disabled"
        case "rightShoulderOn":
            RIGHTSHOULDERON()
            return "Aim : Right-shoulder Enabled"
        case "rightShoulderOff":
            RIGHTSHOULDEROFF()
            return "Aim : Right-shoulder Disabled"
        case "connectemu":
            streamesp()
            return "Lib connecting"
        case "esplineon":
            espline()
            return "Espline Enabled"
        case "esplineoff":
            esplineoff()
            return "Espline Disabled"
        case "espboxon":
            espboxon()
            return "Espbox Enabled"
        case "espboxoff":
            espboxoff()
            return "Espbox Disabled"
        case "espboxooff":
            espboxoff()
            return "Espbox Disabled"
        case "espinfoon":
            espname()
            esphealth()
            espskeleton()
            return "Esp information Enabled"
        case "espinfooff":
            espnameoff()
            esphealthoff()
            espskeletonoff()
            return "Esp information Disabled"
        case "streamer":
            streamermode()
            return "Streamer Mode Enabled"
        case "streameroff":
            streamermodeoff()
            return "Streamer Mode Disabled"
        case "aimbotv2on":
            aimbotv2on()
            return "Autonomic Aimbot Enabled"
        case "aimbotv2off":
            aimbotv2off()
            return "Autonomic Aimbot Disabled"
        case "blockint":
            block_internet()
            return "Hd-player internet blocked successfully"
        case "unblockint":
            unblock_internet()
            return "Hd-player internet un-blocked successfully"
        case "silentaim":
            silentaim()
            return "Silent Aim Enabled"
        case "silentaimoff":
            silentaimoff()
            return "Silent Aim Disabled"
        case "enablefunction":
            enablefunction()
            return "Enable Function Activated"
        case "enablefunctionoff":
            enablefunctionoff()
            return "Enable Function Deactivated"
        case "aimbotrage":
            aimbotrage()
            return "Aimbot Rage Mode Enabled"
        case "aimbotrageoff":
            aimbotrageoff()
            return "Aimbot Rage Mode Disabled"
        case "leftshoulderon":
            LEFTSHOULDERON()
            return "Aim : Left-shoulder Enabled"
        case "leftshoulderoff":
            LEFTSHOULDEROFF()
            return "Aim : Left-shoulder Disabled"
        case "rightshoulderon":
            RIGHTSHOULDERON()
            return "Aim : Right-shoulder Enabled"
        case "rightshoulderoff":
            RIGHTSHOULDEROFF()
            return "Aim : Right-shoulder Disabled"
        case "drawfov":
            drawfov()
            return "FOV Drawn on Screen"
        case "drawfovoff":
            drawfovoff()
            return "FOV Drawn off from Screen"
        case "espname":
            espname()
            return "ESP Name Enabled"
        case "espnameoff":
            espnameoff()
            return "ESP Name Disabled"
        case "espskeleton":
            espskeleton()
            return "ESP Skeleton Enabled"
        case "espskeletonoff":
            espskeletonoff()
            return "ESP Skeleton Disabled"
        case "espaimtrack":
            espaimtrack()
            return "ESP Aim Track Enabled"
        case "espaimtrackoff":
            espaimtrackoff()
            return "ESP Aim Track Disabled"
        case "norecoil":
            norecoil()
            return "No Recoil Enabled"
        case "norecoiloff":
            norecoiloff()
            return "No Recoil Disabled"
        case "upplayer":
            upplayer()
            return "Up Player Enabled"
        case "upplayeroff":
            upplayeroff()
            return "Up Player Disabled"
        case "telekil":
            telekil()
            return "Tele Kill Enabled"
        case "telekiloff":
            telekiloff()
            return "Tele Kill Disabled"
        case _:
            if command.startswith("aimfov:"):
                value_str = command.split(":")[1]
                try:
                    value = float(value_str)
                    on_fov_change(value)
                    return f"Aim FOV set to: {value}"
                except ValueError:
                    return "Invalid FOV value"
            elif command.startswith("silentaim_mode:"):
                mode_str = command.split(":")[1]
                try:
                    mode_index = int(mode_str)
                    return set_silentaim_mode(mode_index)
                except ValueError:
                    return "Invalid mode index"
            else:
                return f"Unknown command: {command}"


def get_lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


@app.route('/lan-info')
def lan_info():
    ip = get_lan_ip()
    return jsonify({
        "pc_url": f"http://127.0.0.1:{5000}",
        "mobile_url": f"http://{ip}:5000",
        "note": "Phone must be on the same WiFi as this PC",
    })


def _open_browser():
    time.sleep(1.5)
    webbrowser.open('http://127.0.0.1:5000')
    ip = get_lan_ip()
    print(f"[panel] PC:    http://127.0.0.1:5000")
    print(f"[panel] Phone: http://{ip}:5000  (same WiFi)")


if __name__ == '__main__':
    # Auto-enable streamer mode in background on app startup.
    threading.Thread(target=_auto_enable_streamer_mode, daemon=True).start()
    threading.Thread(target=_open_browser, daemon=True).start()
    app.run(host='0.0.0.0', port=5000, debug=False)