"""Word-timed lyrics for one track from LRCLIB, as Core.qml reads them:
[{"s": ms, "e": ms, "words": [{"t": str, "s": ms}]}]
"""

import hashlib
import json
import os
import urllib.parse
import urllib.request
from pathlib import Path

import yaml

# Off Windows (dev runs) use a folder of our own, never the Linux app's ~/.cache/starsong.
CACHE = Path(os.environ.get("LOCALAPPDATA") or Path.home() / ".cache" / "starsong-windows") / "starsong" / "cache"
USER_AGENT = "starsong/0.1 (https://github.com/C0deRatoR/starsong)"
TIMEOUT_S = 10
DURATION_TOLERANCE_S = 3


def http_get(url: str, limit: int = 20_000_000) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
        data = resp.read(limit + 1)
    if len(data) > limit:
        raise ValueError(f"response from {url} is larger than {limit} bytes")
    return data


def pick_candidate(candidates: list[dict], duration_s: float) -> dict | None:
    """Closest-duration synced entry, preferring ones with real word timings."""
    usable = [
        c for c in candidates
        if isinstance(c, dict)
        and c.get("syncedLyrics")
        and isinstance(c.get("duration"), (int, float))
        and abs(c["duration"] - duration_s) <= DURATION_TOLERANCE_S
    ]
    usable.sort(key=lambda c: (not c.get("hasWordSync"), abs(c["duration"] - duration_s)))
    return usable[0] if usable else None


def estimate_words(text: str, start: int, end: int) -> list[dict]:
    """Spread a line's words over its time by character count (LRC has no word timings)."""
    words = text.split()
    if not words:
        return []
    total = sum(len(w) for w in words)
    out, t = [], start
    for w in words:
        out.append({"t": w + " ", "s": round(t)})
        t += (end - start) * len(w) / total
    out[-1]["t"] = words[-1]
    return out


def parse_lrc(lrc: str, duration_ms: int) -> list[dict]:
    """Line-timed LRC -> lines with estimated word timings."""
    stamped = []
    for raw in lrc.splitlines():
        if not raw.startswith("[") or "]" not in raw:
            continue
        stamp, text = raw[1:].split("]", 1)
        try:
            mm, ss = stamp.split(":")
            ms = round((int(mm) * 60 + float(ss)) * 1000)
        except ValueError:
            continue  # metadata tags like [ar:...]
        stamped.append((ms, text.strip()))
    stamped.sort(key=lambda x: x[0])

    lines = []
    for i, (start, text) in enumerate(stamped):
        if not text:
            continue  # blank LRC lines only mark the end of the previous line
        next_start = stamped[i + 1][0] if i + 1 < len(stamped) else duration_ms
        # shortcut: assumes ~12 chars/s singing so a long instrumental gap doesn't stretch
        # the last word; real word timings (lyricsfile) replace this when available.
        sung_until = min(next_start, start + len(text) * 85 + 500)
        lines.append({"s": start, "e": next_start, "words": estimate_words(text, start, sung_until)})
    return lines


def parse_lyricsfile(doc: str) -> list[dict]:
    """LRCLIB's YAML lyricsfile -> lines with real word timings."""
    data = yaml.safe_load(doc)
    lines = []
    for line in (data or {}).get("lines") or []:
        text = str(line.get("text") or "").strip()
        start, end = line.get("start_ms"), line.get("end_ms")
        if not text or not isinstance(start, int) or not isinstance(end, int):
            continue
        words = [
            {"t": str(w["text"]), "s": w["start_ms"]}
            for w in line.get("words") or []
            if isinstance(w, dict) and isinstance(w.get("start_ms"), int) and w.get("text")
        ]
        lines.append({"s": start, "e": end, "words": words or estimate_words(text, start, end)})
    return lines


def fetch_lines(artist: str, title: str, duration_s: float) -> tuple[list[dict], bool]:
    query = urllib.parse.urlencode({"track_name": title, "artist_name": artist})
    candidates = json.loads(http_get(f"https://lrclib.net/api/search?{query}"))
    best = pick_candidate(candidates if isinstance(candidates, list) else [], duration_s)
    if best is None:
        return [], False
    if best.get("hasWordSync") and best.get("lyricsfile"):
        lines = parse_lyricsfile(best["lyricsfile"])
        if lines:
            return lines, True
    return parse_lrc(best["syncedLyrics"], round(duration_s * 1000)), False


def lookup(artist: str, title: str, duration_s: float) -> list[dict]:
    """Lines for one track, from the cache or LRCLIB. Raises on network or HTTP errors."""
    key = hashlib.sha1(f"{artist}\n{title}\n{round(duration_s)}".encode()).hexdigest()
    cached = CACHE / "lyrics" / f"{key}.json"
    if cached.exists():
        return json.loads(cached.read_text(encoding="utf-8"))["lines"]
    lines, word_sync = fetch_lines(artist, title, duration_s)
    if lines:  # don't cache misses: lyrics may be added to LRCLIB later
        cached.parent.mkdir(parents=True, exist_ok=True)
        cached.write_text(json.dumps({"lines": lines, "wordSync": word_sync}), encoding="utf-8")
    return lines
