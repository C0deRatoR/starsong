// Every user setting. starsong.py loads them from %APPDATA%\starsong\settings.json and saves
// each change straight back.
import QtQuick

QtObject {
    // Lyrics
    property string style: "constellation" // constellation | fisheye | karaoke | wall | off
    property string fontFamily: "Quicksand"
    property int fontWeight: 500
    property real textScale: 1
    property real lyricsOffsetMs: 0 // + shows lyrics later, - earlier, for players or sources that drift
    property bool beatWords: true // the word being sung pulses on each beat
    property bool nowPlaying: true
    property string nowPlayingCorner: "bottom-left" // top-left | top-right | bottom-left | bottom-right

    // Stars (constellation)
    property real starScale: 1
    property real haloStrength: 1
    property bool twinkle: true
    property bool comets: true
    property bool ripples: true
    property bool drift: true

    // Backdrop
    property bool backdrop: true
    property real backdropDim: 0.32
    property real backdropSpeed: 1
    property bool dust: true

    // Edge glow
    property bool glow: true
    property real glowIntensity: 1
    property real glowThickness: 48
    property real glowBass: 1
    property string glowMode: "waves" // still | waves | orbit | twin | breathe | aurora | ripple
    property real glowFlowSpeed: 1

    // Colours: "album", a preset name (see Core.qml), "cycle" (all presets in turn),
    // or "custom" (colorA + colorB)
    property string colors: "album"
    property real cycleSeconds: 30
    property string colorA: "#8b5cf6"
    property string colorB: "#3b82f6"
}
