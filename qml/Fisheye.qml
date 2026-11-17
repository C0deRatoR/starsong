// Fisheye lyrics: a stack of lines seen through a convex lens. The line being sung sits
// in the middle, magnified, and lights up word by word; the stack scrolls as lines change.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property var lines: []
    property int focusIndex: -1
    property bool active // false during long instrumental breaks
    property real posMs
    property color accent
    property real level // bass, 0..1
    property string fontFamily
    required property var cfg
    property int beats

    readonly property int lineHeight: Math.round(92 * cfg.textScale)
    readonly property int visibleLines: 9 // rendered above + below the focus, the lens squeezes the rest
    readonly property int maxWordMs: 1500 // a word's fill never takes longer than this

    // Beat pulse for the focus line; a Scale transform so it stacks on the fit-to-width scale.
    property real pulse: 1
    onBeatsChanged: if (cfg.beatWords && active) beat.restart()
    NumberAnimation { id: beat; target: root; property: "pulse"; from: 1.08; to: 1; duration: 380; easing.type: Easing.OutCubic }

    Item {
        id: lensArea
        width: Math.min(root.width * 0.85, 1800)
        height: root.lineHeight * 8
        anchors.centerIn: parent
        scale: 1 + root.level * 0.025 // breathes with the bass
        opacity: root.active ? 1 : 0.35
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }

        // The flat stack, rendered offscreen and fed to the lens shader.
        Item {
            id: stack
            width: lensArea.width
            height: root.lineHeight * root.visibleLines
            visible: false

            Item {
                id: track
                width: parent.width
                // Scroll so the focus line's centre sits in the middle of the stack.
                y: stack.height / 2 - (Math.max(root.focusIndex, 0) + 0.5) * root.lineHeight
                Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }

                Repeater {
                    model: root.lines
                    Row {
                        id: lineItem
                        required property var modelData
                        required property int index
                        readonly property bool near: Math.abs(index - root.focusIndex) <= Math.ceil(root.visibleLines / 2)
                        readonly property bool isFocus: index === root.focusIndex

                        visible: near // only build what the lens can show
                        x: (track.width - width) / 2
                        y: index * root.lineHeight + (root.lineHeight - height) / 2
                        scale: Math.min(1, track.width / Math.max(width, 1)) // shrink lines too long to fit
                        transform: Scale {
                            origin.x: lineItem.width / 2; origin.y: lineItem.height / 2
                            xScale: lineItem.isFocus ? root.pulse : 1; yScale: lineItem.isFocus ? root.pulse : 1
                        }

                        Repeater {
                            model: lineItem.near ? lineItem.modelData.words : []
                            Item {
                                id: word
                                required property var modelData
                                required property int index
                                // 0..1 through this word on the focus line; fills left to right.
                                readonly property real progress: {
                                    if (!lineItem.isFocus || root.posMs < modelData.s)
                                        return 0;
                                    const words = lineItem.modelData.words;
                                    const next = index + 1 < words.length ? words[index + 1].s : lineItem.modelData.e;
                                    const dur = Math.min(Math.max(next - modelData.s, 1), root.maxWordMs);
                                    return Math.min((root.posMs - modelData.s) / dur, 1);
                                }
                                width: base.implicitWidth
                                height: base.implicitHeight

                                Text {
                                    id: base
                                    text: word.modelData.t
                                    font.pixelSize: Math.round(58 * root.cfg.textScale)
                                    font.family: root.fontFamily
                                    font.weight: root.cfg.fontWeight
                                    color: Qt.rgba(1, 1, 1, lineItem.isFocus ? 0.5 : 0.35)
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }
                                Item {
                                    width: base.implicitWidth * word.progress
                                    height: base.implicitHeight
                                    clip: true
                                    Text {
                                        text: base.text
                                        font: base.font
                                        color: root.accent
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ShaderEffect {
            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("shaders/lens.frag.qsb")
            property var source: ShaderEffectSource {
                sourceItem: stack
                // The lens magnifies the middle ~1.4x; render at 2x so it stays sharp.
                textureSize: Qt.size(stack.width * 2, stack.height * 2)
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.45
                shadowBlur: 1
            }
        }
    }
}
