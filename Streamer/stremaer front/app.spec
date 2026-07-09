# -*- mode: python ; coding: utf-8 -*-
# Portable one-file build: pyinstaller --noconfirm --clean app.spec
# Output: dist/AnsariCheats.exe

from PyInstaller.utils.hooks import collect_submodules

block_cipher = None

hiddenimports = collect_submodules('flask') + [
    'pynput.keyboard._win32', 'pynput.mouse._win32',
    'win32api', 'win32security', 'win32process', 'win32gui',
]

datas = [
    ('index.html', '.'),
    ('login.html', '.'),
    ('test.html', '.'),
    ('bg main', 'bg main'),
    ('video sound', 'video sound'),
    ('devimage', 'devimage'),
]

binaries = [
    ('AotBst.dll', '.'),
    ('cimgui.dll', '.'),
    ('BOX.dll', '.'),
    ('wallfixedchams.dll', '.'),
]

a = Analysis(
    ['app.py'],
    pathex=['.'],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='AnsariCheats',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
