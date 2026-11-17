// Now playing: the title and artist set in type straight on the backdrop (no card), with the
// progress drawn as a beam of light and a small star riding the playhead, the same star the
// constellation uses. Album colours only, never the cover. Corner is picked in settings.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: np

    required property var app
    property color accent
    property string fontFamily

    readonly property var cfg: app.cfg
    readonly property var player: app.player
    readonly property real s: cfg.textScale
    readonly property real lengthMs: (player?.length ?? 0) * 1000
    readonly property real progress: lengthMs > 0 ? Math.min(app.posMs / lengthMs, 1) : 0
    readonly property string corner: cfg.nowPlayingCorner // top-left | top-right | bottom-left | bottom-right
    readonly property bool onRight: corner.endsWith("right")
    readonly property int margin: 56
    readonly property int barClearance: 44 // keep top corners clear of waybar

    visible: opacity > 0
    opacity: cfg.nowPlaying && player && player.trackTitle ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }

    width: Math.min(560 * s, parent.width * 0.4)
    height: column.implicitHeight
    x: onRight ? parent.width - width - margin : margin
    y: corner.startsWith("top") ? margin + barClearance : parent.height - height - margin

    // The title dips out and back in when the song changes, instead of snapping.
    readonly property string trackKey: (player?.trackTitle ?? "") + (player?.trackArtist ?? "")
    onTrackKeyChanged: swap.restart()
    SequentialAnimation {
        id: swap
        NumberAnimation { target: column; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InQuad }
        NumberAnimation { target: column; property: "opacity"; to: 1; duration: 520; easing.type: Easing.OutCubic }
    }

    Column {
        id: column
        width: parent.width
        spacing: 6 * np.s

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.4
            shadowBlur: 1
        }

        Text {
            width: parent.width
            horizontalAlignment: np.onRight ? Text.AlignRight : Text.AlignLeft
            text: np.player?.trackTitle ?? ""
            elide: Text.ElideRight
            color: Qt.rgba(0.97, 0.95, 0.92, 0.95)
            font.family: np.fontFamily
            font.weight: Font.Normal
            font.pixelSize: 30 * np.s
            font.letterSpacing: 0.3
        }
        Text {
            width: parent.width
            horizontalAlignment: np.onRight ? Text.AlignRight : Text.AlignLeft
            text: np.player?.trackArtist ?? ""
            elide: Text.ElideRight
            color: Qt.rgba(0.97, 0.95, 0.92, 0.55)
            font.family: np.fontFamily
            font.pixelSize: 17 * np.s
            font.letterSpacing: 0.4
        }

        Item { width: 1; height: 10 * np.s }

        // Beam: a faint hairline, the travelled part lit in the album colour, a star at the playhead.
        Item {
            id: beam
            width: 260 * np.s
            height: 18 * np.s
            x: np.onRight ? parent.width - width : 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.16)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * np.progress
                height: 1.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.lighter(np.accent, 1.3) }
                }
            }
            Item {
                x: parent.width * np.progress
                anchors.verticalCenter: parent.verticalCenter
                scale: 1 + np.app.bass * 0.3 // breathes with the music, like the stars
                Shape {
                    width: 28; height: 28; x: -14; y: -14
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: 14; centerY: 14; centerRadius: 14
                            focalX: 14; focalY: 14
                            GradientStop { position: 0; color: "white" }
                            GradientStop { position: 0.25; color: Qt.alpha(Qt.lighter(np.accent, 1.5), 0.7) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        PathAngleArc { centerX: 14; centerY: 14; radiusX: 14; radiusY: 14; sweepAngle: 360 }
                    }
                }
                Rectangle { width: 16; height: 1; x: -8; color: Qt.rgba(1, 1, 1, 0.6) } // diffraction spikes
                Rectangle { width: 1; height: 16; y: -8; color: Qt.rgba(1, 1, 1, 0.6) }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: np.onRight ? -width - 14 * np.s : parent.width + 14 * np.s
                text: `${np.clock(np.app.posMs)} / ${np.clock(np.lengthMs)}`
                color: Qt.rgba(0.97, 0.95, 0.92, 0.45)
                font.family: np.fontFamily
                font.pixelSize: 12 * np.s
                font.features: { "tnum": 1 } // fixed-width digits so the time doesn't jitter
            }
        }
    }

    function clock(ms) {
        const sec = Math.max(0, Math.floor(ms / 1000));
        return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;
    }
}
