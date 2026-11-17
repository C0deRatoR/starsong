// Demo mode (starsong.py --demo): a stand-in player with original lyrics and a steady beat, so the
// scenes can be shown or recorded without music playing. It has the MediaPlayer fields Core.qml reads.
import QtQuick

QtObject {
    id: demo

    readonly property string trackTitle: "Every Word a Star"
    readonly property string trackArtist: "Starsong"
    readonly property string trackArtUrl: ""
    readonly property bool isPlaying: true
    readonly property real length: 214 // seconds
    readonly property int bpm: 96

    readonly property var lyrics: [
        "Every word I sing becomes a star",
        "Drawn across the dark to where you are",
        "Hold the light and let the colours flow",
        "Follow every line until it glows",
        "Under neon skies we come alive",
        "Counting constellations, you and I",
        "Turn the music up and watch it shine",
        "Every beat is written in the sky",
    ]
    readonly property int lineMs: 4200
    readonly property int startMs: 61000 // lyrics begin a minute in, so the progress beam sits partway
    readonly property int loopMs: lyrics.length * lineMs + 1600

    // Same shape as fetch_lyrics.py output: words spread over each line by character count.
    readonly property var lines: lyrics.map((text, i) => {
        const s = startMs + i * lineMs;
        const e = s + lineMs - 500;
        const words = text.split(" ");
        const total = words.reduce((n, w) => n + w.length, 0);
        let t = s;
        return { s: s, e: e, words: words.map((w, k) => {
            const word = { t: k < words.length - 1 ? w + " " : w, s: Math.round(t) };
            t += (e - s) * w.length / total;
            return word;
        }) };
    })

    // Position in seconds, looping over the lyrics.
    property real position: startMs / 1000
    readonly property real startedAt: Date.now()
    function tick() {
        position = (startMs - 800 + (Date.now() - startedAt) % loopMs) / 1000;
    }
}
