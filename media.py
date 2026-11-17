"""What Windows is playing, from its media controls (the same source as the volume flyout).

MediaPlayer has the fields Core.qml reads from a player: trackTitle, trackArtist, isPlaying,
length and position (seconds), plus the album's colours."""

import asyncio
import io
import logging
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone

from PIL import Image
from PySide6.QtCore import Property, QObject, Signal, Slot

log = logging.getLogger(__name__)

POLL_S = 0.5
ART_SIZE = 64
ART_COLORS = 8


def album_colors(image_bytes: bytes) -> list[str]:
    """The album art's main colours as "#rrggbb", most common first."""
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image.thumbnail((ART_SIZE, ART_SIZE))
    quantized = image.quantize(colors=ART_COLORS)
    palette = quantized.getpalette()
    counts = sorted(quantized.getcolors(), reverse=True)
    return ["#%02x%02x%02x" % tuple(palette[i * 3 : i * 3 + 3]) for _, i in counts]


@dataclass(frozen=True)
class Snapshot:
    title: str
    artist: str
    playing: bool
    length: float  # seconds, 0 when the player doesn't say
    position: float  # seconds, at `taken`
    taken: float  # time.monotonic()


class MediaPlayer(QObject):
    changed = Signal()
    positionChanged = Signal()  # Core.qml emits it every frame, so `position` is read fresh
    _snapshot = Signal(object)
    _colors = Signal(list)

    def __init__(self) -> None:
        super().__init__()
        self._now: Snapshot | None = None
        self._album_colors: list[str] = []
        self._snapshot.connect(self._apply)
        self._colors.connect(self._apply_colors)
        threading.Thread(target=lambda: asyncio.run(self._poll()), name="media", daemon=True).start()

    # --- Read from QML -----------------------------------------------------------------------
    hasSession = Property(bool, lambda self: self._now is not None, notify=changed)
    trackTitle = Property(str, lambda self: self._now.title if self._now else "", notify=changed)
    trackArtist = Property(str, lambda self: self._now.artist if self._now else "", notify=changed)
    isPlaying = Property(bool, lambda self: bool(self._now and self._now.playing), notify=changed)
    length = Property(float, lambda self: self._now.length if self._now else 0.0, notify=changed)
    albumColors = Property(list, lambda self: self._album_colors, notify=changed)

    def _position(self) -> float:
        now = self._now
        if now is None:
            return 0.0
        position = now.position + (time.monotonic() - now.taken if now.playing else 0)
        return min(position, now.length) if now.length > 0 else position

    position = Property(float, _position, notify=positionChanged)

    @Slot(object)
    def _apply(self, snapshot: Snapshot | None) -> None:
        self._now = snapshot
        self.changed.emit()
        self.positionChanged.emit()

    @Slot(list)
    def _apply_colors(self, colors: list) -> None:
        self._album_colors = colors
        self.changed.emit()

    # --- Worker thread -----------------------------------------------------------------------
    async def _poll(self) -> None:
        # Windows only (see pyproject.toml); imported here so the rest loads anywhere.
        from winrt.windows.media.control import (
            GlobalSystemMediaTransportControlsSessionManager as Manager,
            GlobalSystemMediaTransportControlsSessionPlaybackStatus as Status,
        )

        manager = await Manager.request_async()
        art_track = None  # the track whose colours we have, or are done trying for
        while True:
            try:
                sessions = list(manager.get_sessions())
                # Prefer whatever is playing; otherwise the current one, so lyrics stay while paused.
                playing = [s for s in sessions if s.get_playback_info().playback_status == Status.PLAYING]
                session = playing[0] if playing else manager.get_current_session()
                if session is None:
                    self._snapshot.emit(None)
                else:
                    props = await session.try_get_media_properties_async()
                    snapshot = self._read(session, props, session.get_playback_info().playback_status == Status.PLAYING)
                    self._snapshot.emit(snapshot)
                    track = (snapshot.artist, snapshot.title)
                    # Some players add the art a moment after the title, so retry until it's there.
                    if track != art_track and props.thumbnail is not None:
                        art_track = track
                        self._colors.emit(album_colors(await read_stream(props.thumbnail)))
            except Exception:  # a player quitting mid-read; the next poll starts fresh
                log.exception("reading the media session failed")
            await asyncio.sleep(POLL_S)

    @staticmethod
    def _read(session, props, playing: bool) -> Snapshot:
        timeline = session.get_timeline_properties()
        length = max(0.0, (timeline.end_time - timeline.start_time).total_seconds())
        position = timeline.position.total_seconds()
        # Players update the timeline only now and then, so carry it forward to now.
        since = (datetime.now(timezone.utc) - timeline.last_updated_time).total_seconds()
        if playing and 0 < since < 24 * 3600:  # a zero timestamp means the player never set it
            position += since
        return Snapshot(props.title or "", props.artist or "", playing, length, position, time.monotonic())


async def read_stream(reference) -> bytes:
    from winrt.windows.storage.streams import DataReader

    stream = await reference.open_read_async()
    reader = DataReader(stream.get_input_stream_at(0))
    size = await reader.load_async(stream.size)
    data = bytearray(size)
    reader.read_bytes(data)
    return bytes(data)
