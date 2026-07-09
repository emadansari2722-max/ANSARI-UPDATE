import os
import sys
import urllib.request


def _base_dir():
    try:
        return sys._MEIPASS
    except Exception:
        return os.path.dirname(os.path.abspath(__file__))


def _local_version_path():
    return os.path.join(_base_dir(), "streamer_version.txt")


def get_local_streamer_version():
    path = _local_version_path()
    if os.path.isfile(path):
        return open(path, encoding="utf-8").read().strip()
    return "0"


def save_local_streamer_version(version: str):
    with open(_local_version_path(), "w", encoding="utf-8") as f:
        f.write(version.strip())


def check_and_update_streamer_dll(keyauthapp):
    """
    KeyAuth app variables (dashboard):
      - streamer_version  e.g. 2.0
      - streamer_url      direct DLL URL on GitHub
    """
    remote_version = keyauthapp.fetch_var("streamer_version")
    download_url = keyauthapp.fetch_var("streamer_url")

    if not remote_version or not download_url:
        print("[update] KeyAuth variables streamer_version / streamer_url not set")
        return False

    local_version = get_local_streamer_version()
    dll_path = os.path.join(_base_dir(), "Streamer.dll")

    if local_version == remote_version and os.path.isfile(dll_path):
        print(f"[update] Streamer.dll already v{local_version}")
        return False

    print(f"[update] Downloading Streamer.dll v{remote_version}...")
    try:
        req = urllib.request.Request(
            download_url,
            headers={"User-Agent": "AnsariCheats-Updater/1.0"},
        )
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
        with open(dll_path, "wb") as f:
            f.write(data)
        save_local_streamer_version(remote_version)
        print(f"[update] Streamer.dll updated to v{remote_version}")
        return True
    except Exception as e:
        print(f"[update] Download failed: {e}")
        return False
