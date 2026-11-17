// Apple Music-style living backdrop: the album's colours (never the cover itself) as large soft
// blobs drifting into each other. Replaces the wallpaper while music plays, so lyrics and glow
// look the same on any wallpaper.
import QtQuick
import QtQuick.Effects
import QtQuick.Particles

Item {
    id: root

    property var colors: [] // album palette, from ColorQuantizer
    property bool shown
    property real level // bass, 0..1
    required property var cfg

    // Most vivid first; darker ones still join so the gradient keeps depth.
    readonly property var blobColors: [...colors]
        .sort((a, b) => b.hsvSaturation * b.hsvValue - a.hsvSaturation * a.hsvValue)
        .slice(0, 5)

    opacity: shown && blobColors.length > 0 ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 1500; easing.type: Easing.InOutSine } }

    // Composed tiny, then stretched to the screen: the upscale does most of the blurring for free,
    // so this stays cheap even though it animates every frame.
    readonly property int lowWidth: 96
    readonly property int lowHeight: Math.max(1, Math.round(lowWidth * height / Math.max(width, 1)))

    // The blur fades the field's own edges to transparent (about 32 of its 96 pixels), so it
    // overhangs the screen by 35% on every side, and a solid base underneath catches the rest:
    // the wallpaper must never show through.
    readonly property real overhang: 0.35
    readonly property color baseColor: blobColors.length ? Qt.darker(blobColors[blobColors.length - 1], 2.5) : "black"

    Rectangle {
        anchors.fill: parent
        color: root.baseColor
        Behavior on color { ColorAnimation { duration: 2500 } }
    }

    Item {
        id: field
        width: root.lowWidth * (1 + 2 * root.overhang)
        height: root.lowHeight * (1 + 2 * root.overhang)
        x: -root.width * root.overhang
        y: -root.height * root.overhang
        transformOrigin: Item.TopLeft
        scale: root.width / root.lowWidth
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 32
            saturation: 0.25
        }

        Rectangle {
            anchors.fill: parent
            color: root.baseColor
            Behavior on color { ColorAnimation { duration: 2500 } }
        }

        Repeater {
            model: 5
            Rectangle {
                id: blob
                required property int index
                // Each blob wanders between two spots on its own slow loop.
                readonly property real d: 0.55 + 0.12 * (index % 3)
                width: field.height * (1.1 - index * 0.12)
                height: width
                radius: width / 2
                color: root.blobColors.length ? root.blobColors[index % root.blobColors.length] : "black"
                Behavior on color { ColorAnimation { duration: 2500 } }

                property real fx: [0.2, 0.8, 0.5, 0.1, 0.9][index]
                property real fy: [0.3, 0.7, 0.2, 0.9, 0.4][index]
                x: field.width * fx - width / 2
                y: field.height * fy - height / 2

                SequentialAnimation on fx {
                    running: root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: [0.7, 0.25, 0.85, 0.5, 0.35][blob.index]; duration: (17000 + blob.index * 4100) / root.cfg.backdropSpeed; easing.type: Easing.InOutSine }
                    NumberAnimation { to: [0.2, 0.8, 0.5, 0.1, 0.9][blob.index]; duration: (17000 + blob.index * 4100) / root.cfg.backdropSpeed; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on fy {
                    running: root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: [0.75, 0.2, 0.65, 0.35, 0.95][blob.index]; duration: (23000 + blob.index * 3300) / root.cfg.backdropSpeed; easing.type: Easing.InOutSine }
                    NumberAnimation { to: [0.3, 0.7, 0.2, 0.9, 0.4][blob.index]; duration: (23000 + blob.index * 3300) / root.cfg.backdropSpeed; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // Dim so white lyrics always read; lifts a touch on each bass hit so the room breathes.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Math.max(0, root.cfg.backdropDim - root.level * 0.1))
    }

    // Shade toward the screen edges, so the edge glow sits against shadow and stands apart.
    readonly property real shadeSize: Math.min(width, height) * 0.16
    Repeater {
        model: [
            { x: 0, y: 0, w: 1, h: 0, horizontal: false, flip: false },  // top
            { x: 0, y: 1, w: 1, h: 0, horizontal: false, flip: true },   // bottom
            { x: 0, y: 0, w: 0, h: 1, horizontal: true, flip: false },   // left
            { x: 1, y: 0, w: 0, h: 1, horizontal: true, flip: true },    // right
        ]
        Rectangle {
            required property var modelData
            visible: root.cfg.glow
            width: modelData.w ? root.width : root.shadeSize
            height: modelData.h ? root.height : root.shadeSize
            x: modelData.x ? root.width - width : 0
            y: modelData.y ? root.height - height : 0
            gradient: Gradient {
                orientation: modelData.horizontal ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: modelData.flip ? 1 : 0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: modelData.flip ? 0 : 1; color: "transparent" }
            }
        }
    }

    // Faint dust drifting upward through the light.
    ParticleSystem {
        id: dust
        running: root.visible
    }
    Emitter {
        anchors.fill: parent
        system: dust
        enabled: root.cfg.dust
        emitRate: 5
        lifeSpan: 16000
        lifeSpanVariation: 4000
        size: 9
        sizeVariation: 6
        velocity: AngleDirection { angle: -90; angleVariation: 25; magnitude: 10; magnitudeVariation: 7 }
    }
    ImageParticle {
        system: dust
        source: "qrc:///particleresources/glowdot.png"
        color: Qt.rgba(1, 1, 1, 0.45)
        colorVariation: 0.05
        entryEffect: ImageParticle.Fade
    }
}
