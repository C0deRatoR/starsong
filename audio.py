"""Bass level of whatever Windows is playing, for the beat: WASAPI loopback of the default output."""

import logging
import threading
import time

import numpy as np
from PySide6.QtCore import Property, QObject, Signal

log = logging.getLogger(__name__)

RATE = 48000
BLOCK = 1024  # ~47 readings a second
WINDOW = 2048  # FFT size: 23 Hz bins, fine enough to pick out the bass band
BASS_HZ = (45, 140)  # kick drum and bass line; the band cava's lowest bars covered on Linux
SILENCE = 2e-3  # band amplitude (full scale = 0.25) below which the level is 0
PEAK_DECAY = 0.998  # autosens: the loudest recent bass sets 1.0, forgotten over ~10 s
RETRY_S = 2


class BassMeter:
    """Turns blocks of mono samples into a 0..1 bass level, scaled to the music's own loudness."""

    def __init__(self) -> None:
        self.buffer = np.zeros(WINDOW, dtype=np.float32)
        self.peak = 0.0
        freqs = np.fft.rfftfreq(WINDOW, 1 / RATE)
        self.band = (freqs >= BASS_HZ[0]) & (freqs <= BASS_HZ[1])
        self.hann = np.hanning(WINDOW).astype(np.float32)

    def feed(self, samples: np.ndarray) -> float:
        n = min(len(samples), WINDOW)
        self.buffer = np.roll(self.buffer, -n)
        self.buffer[-n:] = samples[-n:]
        spectrum = np.abs(np.fft.rfft(self.buffer * self.hann)) / WINDOW
        amplitude = float(np.sqrt(np.sum(spectrum[self.band] ** 2)))
        self.peak = max(amplitude, self.peak * PEAK_DECAY)
        if amplitude < SILENCE:
            return 0.0
        return amplitude / self.peak


class Audio(QObject):
    """Emits `level` while `active` (set from QML: only while music plays)."""

    level = Signal(float)
    activeChanged = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._active = False
        self._thread: threading.Thread | None = None

    def _get_active(self) -> bool:
        return self._active

    def _set_active(self, on: bool) -> None:
        if on == self._active:
            return
        self._active = on
        self.activeChanged.emit()
        if on and not (self._thread and self._thread.is_alive()):
            self._thread = threading.Thread(target=self._run, name="audio", daemon=True)
            self._thread.start()

    active = Property(bool, _get_active, _set_active, notify=activeChanged)

    def _run(self) -> None:
        import soundcard  # Windows only (see pyproject.toml)

        meter = BassMeter()
        while self._active:
            try:
                speaker = soundcard.default_speaker()
                loopback = soundcard.get_microphone(str(speaker.name), include_loopback=True)
                with loopback.recorder(samplerate=RATE, blocksize=BLOCK) as recorder:
                    while self._active:
                        self.level.emit(meter.feed(recorder.record(numframes=BLOCK).mean(axis=1)))
            except Exception:  # device unplugged or switched: log it, then try the new default
                log.exception("audio capture failed, retrying in %s s", RETRY_S)
                time.sleep(RETRY_S)
