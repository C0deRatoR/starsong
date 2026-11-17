// 3D wall lyrics: the current line and the ones before it, stacked left-aligned on a tilted
// plane that drifts slowly. The current line fills word by word; the stack scrolls up as lines change.
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

    readonly property int fontSize: Math.round(46 * cfg.textScale)
    readonly property int lineHeight: Math.round(fontSize * 1.45)
    readonly property int linesAbove: 6 // older lines kept on the wall
    property real pulse: 1 // beat pulse on the current line
    property real yaw // driven by the drift animations below
    property real pitch

    opacity: active ? 1 : 0.35
    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }

    onBeatsChanged: if (cfg.beatWords && active) beat.restart()
    NumberAnimation { id: beat; target: root; property: "pulse"; from: 1.07; to: 1; duration: 380; easing.type: Easing.OutCubic }

    // Different periods for yaw and pitch so the drift never visibly repeats.
    SequentialAnimation on yaw {
        loops: Animation.Infinite
        NumberAnimation { from: -15; to: -8; duration: 6500; easing.type: Easing.InOutSine }
        NumberAnimation { from: -8; to: -22; duration: 13000; easing.type: Easing.InOutSine }
        NumberAnimation { from: -22; to: -15; duration: 6500; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on pitch {
        loops: Animation.Infinite
        NumberAnimation { from: 12; to: 16; duration: 5000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 16; to: 8; duration: 10000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 8; to: 12; duration: 5000; easing.type: Easing.InOutSine }
    }

    // Full-screen so the shadow layer never clips the tilted plane (a layer only draws inside its item).
    Item {
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.45
            shadowBlur: 1
        }

        Item {
            id: plane
            width: Math.min(root.width * 0.7, 1600)
            height: root.lineHeight * (root.linesAbove + 2) // older lines + current + next
            anchors.centerIn: parent
            transform: [
                Rotation { origin.x: plane.width / 2; origin.y: plane.height / 2; axis { x: 0; y: 1; z: 0 } angle: root.yaw },
                Rotation { origin.x: plane.width / 2; origin.y: plane.height / 2; axis { x: 1; y: 0; z: 0 } angle: root.pitch }
            ]

            Item {
                id: track
                width: parent.width
                // Keep the focus line in the second-to-last slot, the next line below it.
                y: (root.linesAbove - root.focusIndex) * root.lineHeight
                Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }

                Repeater {
                    model: root.lines
                    Item {
                        id: lineItem
                        required property var modelData
                        required property int index
                        readonly property int age: root.focusIndex - index // 0 current, <0 upcoming, >0 older
                        // One spare line each side so lines fade in and out instead of popping.
                        readonly property bool near: age >= -2 && age <= root.linesAbove + 1
                        readonly property bool isFocus: age === 0

                        visible: near // only build lines on or next to the wall
                        y: index * root.lineHeight
                        width: track.width
                        height: root.lineHeight
                        opacity: {
                            if (age === 0)
                                return 1;
                            if (age === -1)
                                return 0.3;
                            if (age < -1 || age > root.linesAbove)
                                return 0;
                            return 0.6 - (age - 1) * 0.08; // 0.6 down to 0.2
                        }
                        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                        transform: Scale {
                            origin.y: lineItem.height / 2
                            xScale: lineItem.isFocus ? root.pulse : 1
                            yScale: lineItem.isFocus ? root.pulse : 1
                        }

                        Text {
                            visible: !lineItem.isFocus
                            anchors.verticalCenter: parent.verticalCenter
                            transformOrigin: Item.Left
                            scale: Math.min(1, lineItem.width / Math.max(implicitWidth, 1)) // shrink lines too long to fit
                            text: lineItem.near && !lineItem.isFocus ? lineItem.modelData.words.map(w => w.t).join("") : ""
                            color: Qt.rgba(0.97, 0.95, 0.92, 0.9)
                            font.family: root.fontFamily
                            font.weight: root.cfg.fontWeight
                            font.pixelSize: root.fontSize
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            transformOrigin: Item.Left
                            scale: Math.min(1, lineItem.width / Math.max(width, 1))
                            Repeater {
                                model: lineItem.isFocus ? lineItem.modelData.words.length : 0
                                Word {
                                    required property int index
                                    line: lineItem.modelData
                                    wordIndex: index
                                    posMs: root.posMs
                                    live: true
                                    fillColor: Qt.lighter(root.accent, 1.25)
                                    font.family: root.fontFamily
                                    font.weight: root.cfg.fontWeight
                                    font.pixelSize: root.fontSize
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
