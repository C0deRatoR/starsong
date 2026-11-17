"""Saves the QML settings object (qml/Settings.qml) as JSON and loads it back on start."""

import json
import logging
import os
from pathlib import Path

from PySide6.QtCore import SIGNAL, SLOT, QObject, QTimer, Slot

log = logging.getLogger(__name__)

# Off Windows (dev runs) use a folder of our own, never the Linux app's ~/.config/starsong.
PATH = Path(os.environ.get("APPDATA") or Path.home() / ".config" / "starsong-windows") / "starsong" / "settings.json"
SAVE_DELAY_MS = 200  # sliders change many times a second; write once they settle


def merge(saved: object, defaults: dict) -> dict:
    """Defaults overlaid with the saved values that are known and of the right type.

    The file can be edited by hand, so anything else is dropped with a warning."""
    merged = dict(defaults)
    if not isinstance(saved, dict):
        log.warning("settings file isn't a JSON object, using defaults")
        return merged
    for key, value in saved.items():
        if key not in defaults:
            log.warning("ignoring unknown setting %r", key)
            continue
        default = defaults[key]
        # bool is an int in Python, and JSON writes 1.0 as 1, so numbers are matched loosely.
        if isinstance(default, bool):
            ok = isinstance(value, bool)
        elif isinstance(default, (int, float)):
            ok = isinstance(value, (int, float)) and not isinstance(value, bool)
        else:
            ok = isinstance(value, type(default))
        if ok:
            merged[key] = value
        else:
            log.warning("ignoring setting %r: expected %s, got %r", key, type(default).__name__, value)
    return merged


class SettingsStore(QObject):
    """Fills `values` from the file, then saves every change to it."""

    def __init__(self, values: QObject, path: Path = PATH) -> None:
        super().__init__()
        self.values = values
        self.path = path
        meta = values.metaObject()
        props = [meta.property(i) for i in range(meta.propertyOffset(), meta.propertyCount())]
        self.names = [p.name() for p in props]

        try:
            saved = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            saved = {}
        except (OSError, ValueError) as e:
            log.warning("can't read %s, using defaults: %s", path, e)
            saved = {}
        for key, value in merge(saved, self.snapshot()).items():
            values.setProperty(key, value)

        self.timer = QTimer(singleShot=True, interval=SAVE_DELAY_MS, timeout=self.save)
        for p in props:
            # QML-declared signals aren't Python attributes, so connect by signature.
            signature = bytes(p.notifySignal().methodSignature()).decode()
            QObject.connect(values, SIGNAL(signature), self.timer, SLOT("start()"))
        if saved != self.snapshot():
            self.save()  # first run: write the defaults out so they can be found and edited

    def snapshot(self) -> dict:
        return {name: self.values.property(name) for name in self.names}

    @Slot()
    def save(self) -> None:
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.path.with_suffix(".tmp")
            tmp.write_text(json.dumps(self.snapshot(), indent=2), encoding="utf-8")
            tmp.replace(self.path)  # a crash mid-write never leaves a half-written file
        except OSError as e:
            log.error("can't save settings to %s: %s", self.path, e)
