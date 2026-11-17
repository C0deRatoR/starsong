# PyInstaller build: one windowed Starsong.exe.  uv run pyinstaller Starsong.spec
from PyInstaller.utils.hooks import collect_data_files

a = Analysis(
    ["starsong.py"],
    datas=[("qml", "qml"), *collect_data_files("soundcard")],  # soundcard reads its C headers at runtime
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    name="Starsong",
    console=False,
    upx=False,
)
