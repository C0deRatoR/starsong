// Karaoke lyrics: one big line filling word by word, the previous line above and the next below.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property var cfg
    property var lines: []
    property int focusIndex: -1
    property bool active // false during long instrumental breaks
    property real posMs
    property color accent
    property int beats
    property string fontFamily

    readonly property int bigSize: Math.round(76 * cfg.textScale)
    readonly property var current: focusIndex >= 0 ? lines[focusIndex] : null
    readonly property var previous: focusIndex >= 1 ? lines[focusIndex - 1] : null
    readonly property var next: focusIndex + 1 < lines.length ? lines[focusIndex + 1] : null
    property real pulse: 1 // beat pulse on the current line

    opacity: active ? 1 : 0.35
    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }

    onFocusIndexChanged: enter.restart()
    onBeatsChanged: if (cfg.beatWords && active) beat.restart()
    NumberAnimation { id: beat; target: root; property: "pulse"; from: 1.07; to: 1; duration: 380; easing.type: Easing.OutCubic }

    Column {
        width: parent.width * 0.85
        anchors.centerIn: parent
        spacing: root.bigSize * 0.4

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.45
            shadowBlur: 1
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.previous ? root.previous.words.map(w => w.t).join("") : ""
            color: Qt.rgba(0.97, 0.95, 0.92, 0.4)
            font.family: root.fontFamily
            font.weight: root.cfg.fontWeight
            font.pixelSize: root.bigSize * 0.42
        }

        Item {
            id: currentLine
            width: parent.width
            height: row.height * row.scale
            transform: [
                Translate { id: rise },
                Scale { origin.x: currentLine.width / 2; origin.y: currentLine.height / 2; xScale: root.pulse; yScale: root.pulse }
            ]
            ParallelAnimation {
                id: enter
                NumberAnimation { target: rise; property: "y"; from: 28; to: 0; duration: 480; easing.type: Easing.OutCubic }
                NumberAnimation { target: currentLine; property: "opacity"; from: 0; to: 1; duration: 480; easing.type: Easing.OutCubic }
            }

            Row {
                id: row
                anchors.horizontalCenter: parent.horizontalCenter
                transformOrigin: Item.Top
                scale: Math.min(1, parent.width / Math.max(width, 1)) // shrink lines too long to fit
                Repeater {
                    model: root.current ? root.current.words.length : 0
                    Word {
                        required property int index
                        line: root.current
                        wordIndex: index
                        posMs: root.posMs
                        live: true
                        fillColor: Qt.lighter(root.accent, 1.25)
                        font.family: root.fontFamily
                        font.weight: root.cfg.fontWeight
                        font.pixelSize: root.bigSize
                    }
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.next ? root.next.words.map(w => w.t).join("") : ""
            color: Qt.rgba(0.97, 0.95, 0.92, 0.45)
            font.family: root.fontFamily
            font.weight: root.cfg.fontWeight
            font.pixelSize: root.bigSize * 0.42
        }
    }
}
