// What every view reads: the player, the lyrics and where we are in them, the colours, and the
// beat. starsong.py feeds it the live player, album colours, lyrics and audio level.
import QtQuick

Item {
    id: root

    required property var cfg
    property bool demo: false
    property QtObject livePlayer: null // MediaPlayer from media.py, or null when nothing is playing
    property var albumColors: [] // "#rrggbb" strings, most common first

    // STARSONG demo: a stand-in player (Demo.qml) for showing it without music.
    Demo { id: demoPlayer }
    readonly property QtObject player: demo ? demoPlayer : livePlayer
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real posMs: (player?.position ?? 0) * 1000
    readonly property real lyricsPosMs: posMs - cfg.lyricsOffsetMs // lyrics timing, nudged in settings

    property var lines: []
    property string lyricsStatus: "" // loading | found | none | error, "" between tracks
    readonly property int holdAfterLineMs: 4000 // keep a finished line up this long before clearing
    readonly property int focusIndex: { // last line that has started
        let i = -1;
        for (let k = 0; k < lines.length && lines[k].s <= lyricsPosMs; k++)
            i = k;
        return i;
    }
    readonly property int lineIndex: focusIndex >= 0 && lyricsPosMs > lines[focusIndex].e + holdAfterLineMs ? -1 : focusIndex

    readonly property var styles: ["constellation", "fisheye", "karaoke", "wall", "off"]
    function next(): string {
        cfg.style = styles[(styles.indexOf(cfg.style) + 1) % styles.length];
        return cfg.style;
    }
    function nudge(ms: int): real {
        cfg.lyricsOffsetMs = Math.max(-2000, Math.min(2000, cfg.lyricsOffsetMs + ms)); // the settings slider range
        return cfg.lyricsOffsetMs;
    }

    // Colour presets: five colours each, most important first. They feed the backdrop, and the
    // first two (brightened) the glow and highlights, the same way album colours do.
    readonly property var presets: ({
        monochrome: ["#c8c8c8", "#8a8a8a", "#5a5a5a", "#333333", "#141414"],
        midnight: ["#3b4cca", "#6a5acd", "#2c3e91", "#1e2a78", "#0f1535"],
        aurora: ["#2dd4bf", "#7c3aed", "#22c55e", "#0e7490", "#1e1b4b"],
        sunset: ["#f97316", "#ec4899", "#8b5cf6", "#facc15", "#7c2d12"],
        ocean: ["#0ea5e9", "#14b8a6", "#67e8f9", "#1e3a8a", "#0c4a6e"],
        rose: ["#fb7185", "#f9a8d4", "#be185d", "#fde2e4", "#4c0519"],
        forest: ["#4ade80", "#a3e635", "#166534", "#14532d", "#064e3b"],
    })
    // "cycle" steps through the presets in turn; the colour animations blend each change.
    property int cycleStep: 0
    Timer {
        running: root.cfg.colors === "cycle"
        interval: Math.max(5, root.cfg.cycleSeconds) * 1000
        repeat: true
        onTriggered: root.cycleStep++
    }
    readonly property var presetNames: Object.keys(presets)
    // The demo track has no album art, so "album" falls back to a preset there.
    readonly property string activeColors: cfg.colors === "cycle" ? presetNames[cycleStep % presetNames.length]
        : demo && cfg.colors === "album" ? "sunset" : cfg.colors

    // Colours for the backdrop. Unknown names fall back to the album.
    readonly property var themeColors: activeColors === "custom" ? [Qt.color(cfg.colorA), Qt.color(cfg.colorB)]
        : presets[activeColors] ? presets[activeColors].map(c => Qt.color(c))
        : albumColors.map(c => Qt.color(c))
    // Glow + highlight colours. Custom colours are used exactly as picked.
    readonly property var colorPalette: activeColors === "custom" ? themeColors : pickPalette(themeColors)
    property real bass: 0
    property int beats: 0
    property real lastBeatMs: 0

    // The player's position is extrapolated on read; ask for it every frame while playing.
    FrameAnimation {
        running: root.playing
        onTriggered: root.demo ? demoPlayer.tick() : root.player.positionChanged()
    }

    // --- Lyrics -------------------------------------------------------------------------
    readonly property string trackKey: player ? `${player.trackArtist}\n${player.trackTitle}` : ""
    onTrackKeyChanged: {
        lines = [];
        lyricsStatus = "";
        fetchDelay.restart();
    }
    // Asks starsong.py for lyrics; it answers with lyricsLoaded or lyricsFailed for this key.
    signal fetchRequested(string key, string artist, string title, real length)
    function lyricsLoaded(key: string, found: var): void {
        if (key !== trackKey)
            return; // a newer track started while this one was loading
        lines = Array.isArray(found) ? found : [];
        lyricsStatus = lines.length ? "found" : "none";
    }
    function lyricsFailed(key: string): void {
        if (key === trackKey)
            lyricsStatus = "error";
    }

    // Players can send title, artist and length in separate updates; wait for them to settle.
    Timer {
        id: fetchDelay
        interval: 400
        onTriggered: {
            if (!root.player || !root.player.trackTitle)
                return;
            if (root.demo) {
                root.lines = demoPlayer.lines;
                root.lyricsStatus = "found";
                return;
            }
            root.lyricsStatus = "loading";
            root.fetchRequested(root.trackKey, root.player.trackArtist, root.player.trackTitle, root.player.length);
        }
    }

    // Rounded, airy face for the lyrics (OFL, bundled in fonts/).
    FontLoader {
        id: lyricFont
        source: Qt.resolvedUrl("fonts/Quicksand.ttf")
    }
    readonly property string fontFamily: cfg.fontFamily === "Quicksand" ? lyricFont.name : cfg.fontFamily

    // The same two colours the backdrop leads with, brightened so they glow. Saturation is kept
    // as-is: forcing it up turned muted covers (greys, browns) into neon that clashed with the
    // backdrop. Violet/blue without art.
    function pickPalette(colors) {
        const vivid = [...colors].sort((a, b) => b.hsvSaturation * b.hsvValue - a.hsvSaturation * a.hsvValue);
        // Same hues as the backdrop but richer, so the glow matches without melting into it.
        const lift = c => Qt.hsva(c.hsvHue < 0 ? 0 : c.hsvHue, Math.min(c.hsvSaturation * 1.3, 1), Math.max(c.hsvValue, 0.92), 1);
        if (vivid.length < 2)
            return [Qt.color("#8b5cf6"), Qt.color("#3b82f6")];
        return [lift(vivid[0]), lift(vivid[1])];
    }

    // --- Beat ---------------------------------------------------------------------------
    // One bass reading (0..1) from audio.py, about 45 times a second.
    function feedLevel(raw: real): void {
        // A beat: a clear jump above the running level, at most ~3.5 per second.
        const now = Date.now();
        if (raw > 0.35 && raw > bass * 1.3 && now - lastBeatMs > 280) {
            lastBeatMs = now;
            beats++;
        }
        // Eased toward the new value: quick on a hit, slow to settle, never flickers.
        bass += (raw - bass) * (raw > bass ? 0.45 : 0.07);
    }
    onPlayingChanged: if (!playing) bass = 0

    // The demo's beat, in place of real audio: a hit on every beat that settles like real bass.
    Timer {
        running: root.demo
        interval: 60000 / demoPlayer.bpm
        repeat: true
        onTriggered: {
            root.beats++;
            demoBass.restart();
        }
    }
    NumberAnimation { id: demoBass; target: root; property: "bass"; from: 0.85; to: 0.08; duration: 520; easing.type: Easing.OutCubic }
}
