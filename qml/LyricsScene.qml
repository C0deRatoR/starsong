// Everything drawn on the desktop and in the screensaver: the colour backdrop, the selected
// lyric style and now playing.
import QtQuick
import QtQuick.Effects

Item {
    id: scene

    required property var app // the shell: player, lyrics, colours, beat, settings
    property bool forceBackdrop: false // the screensaver always needs a solid background

    readonly property var cfg: app.cfg
    property color accent: app.colorPalette[0]
    Behavior on accent { ColorAnimation { duration: 2500; easing.type: Easing.InOutSine } }

    Backdrop {
        anchors.fill: parent
        cfg: scene.cfg
        colors: scene.app.themeColors
        shown: scene.app.playing && (scene.cfg.backdrop || scene.forceBackdrop)
        level: scene.app.bass
    }

    Loader {
        anchors.fill: parent
        sourceComponent: ({ constellation: constellation, fisheye: fisheye, karaoke: karaoke, wall: wall })[scene.cfg.style] ?? null
    }

    // Says so when a song has no lyrics, so an empty screen doesn't look broken.
    Text {
        id: notice
        readonly property string message: ({ none: "No lyrics for this song", error: "Couldn't load lyrics" })[scene.app.lyricsStatus] ?? ""
        onMessageChanged: if (message) text = message // keep the old text while it fades out
        anchors.centerIn: parent
        opacity: message && scene.cfg.style !== "off" && scene.app.player ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }
        visible: opacity > 0
        color: "#f7f2eb"
        font.family: scene.app.fontFamily
        font.pixelSize: 22 * scene.cfg.textScale
        font.letterSpacing: 0.5
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowOpacity: 0.4; shadowBlur: 1 }
    }

    NowPlaying {
        app: scene.app
        accent: scene.accent
        fontFamily: scene.app.fontFamily
    }

    Component {
        id: constellation
        Constellation {
            cfg: scene.cfg
            line: scene.app.lineIndex >= 0 ? scene.app.lines[scene.app.lineIndex] : null
            posMs: scene.app.lyricsPosMs
            accent: scene.accent
            level: scene.app.bass
            beats: scene.app.beats
            fontFamily: scene.app.fontFamily
        }
    }

    Component {
        id: fisheye
        Fisheye {
            cfg: scene.cfg
            lines: scene.app.lines
            focusIndex: scene.app.focusIndex
            active: scene.app.lineIndex >= 0
            posMs: scene.app.lyricsPosMs
            accent: scene.accent
            level: scene.app.bass
            beats: scene.app.beats
            fontFamily: scene.app.fontFamily
        }
    }

    Component {
        id: karaoke
        Karaoke {
            cfg: scene.cfg
            lines: scene.app.lines
            focusIndex: scene.app.focusIndex
            active: scene.app.lineIndex >= 0
            posMs: scene.app.lyricsPosMs
            accent: scene.accent
            beats: scene.app.beats
            fontFamily: scene.app.fontFamily
        }
    }

    Component {
        id: wall
        Wall {
            cfg: scene.cfg
            lines: scene.app.lines
            focusIndex: scene.app.focusIndex
            active: scene.app.lineIndex >= 0
            posMs: scene.app.lyricsPosMs
            accent: scene.accent
            beats: scene.app.beats
            fontFamily: scene.app.fontFamily
        }
    }
}
