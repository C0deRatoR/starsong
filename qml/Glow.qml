// Light around the window edges that pulses with the bass.
import QtQuick

ShaderEffect {
    id: glow

    required property var cfg
    property bool shown
    property color colorA
    property color colorB
    Behavior on colorA { ColorAnimation { duration: 2500; easing.type: Easing.InOutSine } }
    Behavior on colorB { ColorAnimation { duration: 2500; easing.type: Easing.InOutSine } }
    property real level // 0..1
    property int beats // goes up by one on every detected beat

    // Motion names in settings -> the shader's mode number.
    readonly property var modes: ({ still: 0, waves: 1, orbit: 2, twin: 3, breathe: 4, aurora: 5, ripple: 6 })
    onBeatsChanged: if (cfg.glowMode === "ripple") rippleAnim.restart()

    fragmentShader: Qt.resolvedUrl("shaders/glow.frag.qsb")
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutSine } }

    property size res: Qt.size(width, height)
    property real intensity: (0.6 + 0.8 * level * cfg.glowBass) * cfg.glowIntensity
    property real thickness: cfg.glowThickness
    property real time: 0
    property real mode: modes[cfg.glowMode] ?? 1
    property real ripple: 1
    NumberAnimation on ripple {
        id: rippleAnim
        running: false
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.OutCubic
    }

    NumberAnimation on time {
        from: 0
        to: 2 * Math.PI
        duration: 12000 / Math.max(0.1, glow.cfg.glowFlowSpeed)
        loops: Animation.Infinite
    }
}
