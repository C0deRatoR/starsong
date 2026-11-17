"""Starsong for Windows: synced lyrics, an album-colour backdrop and a beat-reactive glow, in one window.

Usage: starsong.py [--demo]   (--demo plays a stand-in song, no music or Windows needed)
"""

import argparse
import logging
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PySide6.QtCore import QObject, QtMsgType, QUrl, Signal, Slot, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent

import fetch_lyrics
from settings import SettingsStore

log = logging.getLogger("starsong")

# Bundled files sit in a temp folder when running as the PyInstaller exe.
HERE = Path(getattr(sys, "_MEIPASS", Path(__file__).parent))
LOG_PATH = Path(os.environ.get("LOCALAPPDATA") or Path.home() / ".cache" / "starsong-windows") / "starsong" / "starsong.log"


class Lyrics(QObject):
    """Looks up lyrics off the main thread; answers with loaded or failed for the same key."""

    loaded = Signal(str, list)
    failed = Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self.pool = ThreadPoolExecutor(max_workers=1)

    @Slot(str, str, str, float)
    def fetch(self, key: str, artist: str, title: str, length: float) -> None:
        self.pool.submit(self._fetch, key, artist, title, length)

    def _fetch(self, key: str, artist: str, title: str, length: float) -> None:
        try:
            self.loaded.emit(key, fetch_lyrics.lookup(artist, title, length))
        except Exception:  # offline, LRCLIB down or a bad response: Core shows "Couldn't load lyrics"
            log.exception("lyrics lookup failed for %s - %s", artist, title)
            self.failed.emit(key)


def setup_logging() -> None:
    # The exe has no console, so everything, including QML warnings, goes to a file.
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    handlers = [logging.FileHandler(LOG_PATH, mode="w", encoding="utf-8")]
    if sys.stderr:
        handlers.append(logging.StreamHandler())
    logging.basicConfig(level=logging.INFO, handlers=handlers, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    qml = logging.getLogger("qml")
    levels = {QtMsgType.QtDebugMsg: logging.DEBUG, QtMsgType.QtInfoMsg: logging.INFO, QtMsgType.QtWarningMsg: logging.WARNING}
    qInstallMessageHandler(lambda kind, _context, message: qml.log(levels.get(kind, logging.ERROR), message))


def main() -> int:
    parser = argparse.ArgumentParser(description="Synced lyrics and music visuals in a window.")
    parser.add_argument("--demo", action="store_true", help="play a stand-in song, no music needed")
    args = parser.parse_args()

    setup_logging()
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Starsong")
    engine = QQmlApplicationEngine()

    component = QQmlComponent(engine, QUrl.fromLocalFile(str(HERE / "qml" / "Settings.qml")))
    cfg = component.create()
    if cfg is None:
        log.error("can't load Settings.qml: %s", component.errorString())
        return 1
    store = SettingsStore(cfg)

    lyrics = Lyrics()
    sources = {"cfg": cfg, "lyrics": lyrics, "demo": args.demo}
    if not args.demo:
        # Imported here: their Windows-only parts load in worker threads, and demo mode skips them.
        from audio import Audio
        from media import MediaPlayer

        sources |= {"media": MediaPlayer(), "audio": Audio()}

    engine.setInitialProperties(sources)
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        log.error("can't load Main.qml, see the QML errors above")
        return 1
    log.info("started%s, log at %s", " in demo mode" if args.demo else "", LOG_PATH)
    code = app.exec()
    store.save()
    return code


if __name__ == "__main__":
    sys.exit(main())
