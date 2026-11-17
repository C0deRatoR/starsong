// Constellation lyrics: each sung word becomes a star joined to the previous one,
// the word being sung shows large next to its star and fills in as it is sung.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root

    property var line: null // {s, e, words: [{t, s}]}
    property real posMs
    property color accent
    property real level // bass, 0..1
    required property var cfg
    property string fontFamily
    property int beats

    readonly property int bigFont: Math.round(84 * cfg.textScale)
    readonly property real smallScale: 0.3
    readonly property int maxWordMs: 1500 // a word's fill never takes longer than this
    readonly property int labelGap: 34 // star centre to the start of its word

    // Beat pulse for the word being sung; a Scale transform so it stacks on the label's own scale Behavior.
    property real pulse: 1
    onBeatsChanged: if (cfg.beatWords) beat.restart()
    NumberAnimation { id: beat; target: root; property: "pulse"; from: 1.08; to: 1; duration: 380; easing.type: Easing.OutCubic }

    // The finished line lingers as a fading "ghost" while the new one forms.
    property var lastLine: null
    onLineChanged: {
        ghost.line = lastLine;
        lastLine = line;
        ghostFade.restart();
        current.opacity = 0;
        appear.restart();
    }

    // The shadow layer covers the whole screen: a layer only draws inside its own item, so a
    // smaller one cut off long words and halos that spill past the star field.
    Item {
        anchors.fill: parent

        // Keep the text readable over bright wallpapers.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.45
            shadowBlur: 1
        }

        Item {
            id: field
            width: Math.min(root.width * 0.78, 1700)
            height: Math.min(root.height * 0.58, 720)
            anchors.centerIn: parent

            // A slow float so the sky never sits perfectly still.
            SequentialAnimation on anchors.verticalCenterOffset {
                running: root.cfg.drift
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: -10; duration: 4000; easing.type: Easing.InOutSine }
                NumberAnimation { from: -10; to: 0; duration: 4000; easing.type: Easing.InOutSine }
            }

            Sky {
                id: ghost
                ghost: true
                ParallelAnimation {
                    id: ghostFade
                    NumberAnimation { target: ghost; property: "opacity"; from: 1; to: 0; duration: 700; easing.type: Easing.OutQuad }
                    NumberAnimation { target: ghost; property: "scale"; from: 1; to: 1.06; duration: 700; easing.type: Easing.OutQuad }
                }
            }

            Sky {
                id: current
                line: root.line
                NumberAnimation {
                    id: appear
                    target: current
                    property: "opacity"
                    to: 1
                    duration: 500
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // One line's constellation. A ghost shows every word as already sung and never animates in.
    component Sky: Item {
        id: sky
        property var line: null
        property bool ghost: false
        readonly property var words: line ? line.words : []
        // Same line always gets the same shape: positions are seeded by the line's start time.
        readonly property var points: root.layout(line ? line.s : 0, words, width, height)

        anchors.fill: parent
        opacity: ghost ? 0 : 1

        // Lines first so stars and words sit on top of them.
        Repeater {
            model: sky.words.length
            Rectangle {
                required property int index
                // points and words update in separate bindings, so either can briefly be short.
                readonly property var from: sky.points[index - 1] ?? null
                readonly property var to: sky.points[index] ?? null
                readonly property bool ready: from !== null && to !== null && index < sky.words.length
                readonly property bool drawn: ready && (sky.ghost || root.posMs >= sky.words[index].s)
                visible: ready
                x: ready ? from.x : 0
                y: ready ? from.y : 0
                height: 1
                readonly property real length: ready ? Math.hypot(to.x - from.x, to.y - from.y) : 0
                width: drawn ? length : 0
                opacity: drawn ? 1 : 0
                transformOrigin: Item.Left
                rotation: ready ? Math.atan2(to.y - from.y, to.x - from.x) * 180 / Math.PI : 0
                color: Qt.rgba(1, 1, 1, 0.28)
                antialiasing: true
                Behavior on width { NumberAnimation { duration: 520; easing.type: Easing.InOutSine } }
                Behavior on opacity { NumberAnimation { duration: 300 } }

                // A comet rides the front of the line while it draws, then burns out.
                Item {
                    x: parent.width
                    visible: root.cfg.comets
                    opacity: parent.drawn && parent.width < parent.length - 2 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    Rectangle {
                        width: 46
                        height: 2
                        x: -width
                        y: -0.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Qt.lighter(root.accent, 1.5) }
                        }
                    }
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        x: -2.5
                        y: -2
                        color: "white"
                    }
                }
            }
        }

        Repeater {
            model: sky.words
            Item {
                id: star
                required property var modelData
                required property int index
                readonly property bool sung: sky.ghost || root.posMs >= modelData.s
                readonly property bool current: !sky.ghost && sung
                    && (index === sky.words.length - 1 || root.posMs < sky.words[index + 1].s)
                // 0..1 through this word, drives the left-to-right fill of the big label.
                readonly property real progress: {
                    if (sky.ghost || !current)
                        return sung ? 1 : 0;
                    const next = index + 1 < sky.words.length ? sky.words[index + 1].s : sky.line.e;
                    const dur = Math.min(Math.max(next - modelData.s, 1), root.maxWordMs);
                    return Math.min((root.posMs - modelData.s) / dur, 1);
                }
                readonly property var p: sky.points[index] ?? { x: 0, y: 0 }

                x: p.x
                y: p.y
                z: current ? 1 : 0 // the big word draws over lines and older stars
                opacity: sung ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                onSungChanged: if (sung && root.cfg.ripples) birth.restart()
                onCurrentChanged: if (current) riseIn.restart()
                NumberAnimation { id: riseIn; target: rise; property: "y"; from: 14; to: 0; duration: 450; easing.type: Easing.OutCubic }

                // A soft ripple of light that blooms out once when the star is born.
                Shape {
                    id: ring
                    width: 60
                    height: 60
                    x: -30
                    y: -30
                    opacity: 0
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: 30; centerY: 30; centerRadius: 30
                            focalX: 30; focalY: 30
                            GradientStop { position: 0.55; color: "transparent" }
                            GradientStop { position: 0.8; color: Qt.alpha(root.accent, 0.3) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        PathAngleArc { centerX: 30; centerY: 30; radiusX: 30; radiusY: 30; sweepAngle: 360 }
                    }
                    ParallelAnimation {
                        id: birth
                        NumberAnimation { target: ring; property: "scale"; from: 0.2; to: 1.8; duration: 520; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ring; property: "opacity"; from: 1; to: 0; duration: 520; easing.type: Easing.InQuad }
                    }
                }

                // Starlight: a soft halo, a bright core and thin diffraction spikes, like a star
                // in a long-exposure photo. Everything is centred on the point.
                Item {
                    id: light
                    // Pops in with a small overshoot, then rests smaller once its word has passed.
                    scale: (!star.sung ? 0.15 : star.current ? 1.45 : 0.8) * root.cfg.starScale
                    Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.OutBack } }

                    Item {
                        // Breathes with the bass while its word is being sung.
                        scale: star.current ? (1 + root.level * 0.35) * root.pulse : 1

                        Shape {
                            width: 90
                            height: 90
                            x: -45
                            y: -45
                            opacity: (star.current ? 0.7 : 0.35) * root.cfg.haloStrength
                            Behavior on opacity { NumberAnimation { duration: 500 } }
                            ShapePath {
                                strokeColor: "transparent"
                                fillGradient: RadialGradient {
                                    centerX: 45; centerY: 45; centerRadius: 45
                                    focalX: 45; focalY: 45
                                    GradientStop { position: 0; color: Qt.alpha(root.accent, 0.55) }
                                    GradientStop { position: 0.4; color: Qt.alpha(root.accent, 0.15) }
                                    GradientStop { position: 1; color: "transparent" }
                                }
                                PathAngleArc { centerX: 45; centerY: 45; radiusX: 45; radiusY: 45; sweepAngle: 360 }
                            }
                        }

                        Item {
                            id: spikes
                            // Spikes shimmer: each star breathes on its own rhythm.
                            SequentialAnimation on scale {
                                running: star.sung && root.cfg.twinkle
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.7; duration: 1300 + (star.index * 337) % 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.1; duration: 1300 + (star.index * 337) % 900; easing.type: Easing.InOutSine }
                            }
                            Repeater {
                                // [angle, length, thickness]: long cross plus fainter diagonals.
                                model: [[0, 50, 1.1], [90, 50, 1.1], [45, 20, 0.8], [135, 20, 0.8]]
                                Rectangle {
                                    required property var modelData
                                    width: modelData[1]
                                    height: modelData[2]
                                    x: -width / 2
                                    y: -height / 2
                                    rotation: modelData[0]
                                    antialiasing: true
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.6) }
                                        GradientStop { position: 1; color: "transparent" }
                                    }
                                }
                            }
                        }

                        Shape {
                            width: 16
                            height: 16
                            x: -8
                            y: -8
                            ShapePath {
                                strokeColor: "transparent"
                                fillGradient: RadialGradient {
                                    centerX: 8; centerY: 8; centerRadius: 8
                                    focalX: 8; focalY: 8
                                    GradientStop { position: 0; color: "white" }
                                    GradientStop { position: 0.35; color: star.current ? Qt.lighter(root.accent, 1.7) : Qt.rgba(1, 1, 1, 0.8) }
                                    GradientStop { position: 1; color: "transparent" }
                                }
                                PathAngleArc { centerX: 8; centerY: 8; radiusX: 8; radiusY: 8; sweepAngle: 360 }
                            }
                        }
                    }
                }

                // Big label scaled down once sung, so the shrink animates without relayout.
                Item {
                    id: label
                    x: star.current ? root.labelGap : root.labelGap * 0.6 // small stars need less room
                    Behavior on x { NumberAnimation { duration: 460; easing.type: Easing.OutQuint } }
                    // Box centre sits a little above the letters' visual centre; nudge up to line up with the star.
                    y: -height / 2 - root.bigFont * 0.06
                    width: base.implicitWidth
                    height: base.implicitHeight
                    transformOrigin: Item.Left
                    transform: [
                        Translate { id: rise },
                        Scale { origin.y: label.height / 2; xScale: star.current ? root.pulse : 1; yScale: star.current ? root.pulse : 1 }
                    ]
                    scale: star.current ? 1 : root.smallScale
                    Behavior on scale {
                        NumberAnimation {
                            duration: star.current ? 460 : 560
                            easing.type: star.current ? Easing.OutBack : Easing.OutQuint
                        }
                    }

                    Text {
                        id: base
                        text: star.modelData.t.trim()
                        font.pixelSize: root.bigFont
                        font.family: root.fontFamily
                        font.weight: root.cfg.fontWeight
                        font.letterSpacing: 1
                        color: Qt.rgba(0.97, 0.95, 0.92, 0.35)
                    }
                    // The sung part, revealed left to right.
                    Item {
                        width: base.implicitWidth * star.progress
                        height: base.implicitHeight
                        clip: true
                        Text {
                            text: base.text
                            font: base.font
                            color: Qt.rgba(0.97, 0.95, 0.92, star.current ? 0.95 : 0.75)
                        }
                    }
                }
            }
        }
    }

    // Seeded scatter. Each star keeps a minimum gap from the others and reserves the box its
    // big label covers while it is the current word, so no earlier word ends up under it.
    function layout(seed, words, w, h) {
        let state = (seed | 0) ^ 0x9e3779b9;
        const rand = () => { // mulberry32
            state = (state + 0x6d2b79f5) | 0;
            let t = Math.imul(state ^ (state >>> 15), 1 | state);
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
        // shortcut: label widths are estimated from character count (~0.6em per char), not measured.
        const labelWidth = (text, scale) => labelGap + text.trim().length * bigFont * 0.6 * scale;
        const bigHeight = bigFont * 1.2;
        const minGap = Math.min(w, h) * 0.25;

        const pts = [];
        for (let i = 0; i < words.length; i++) {
            const bigW = Math.min(labelWidth(words[i].t, 1), w);
            let best = null, bestScore = -Infinity;
            for (let tries = 0; tries < 40; tries++) {
                const c = { x: rand() * (w - bigW), y: bigHeight / 2 + rand() * (h - bigHeight) };
                const gap = Math.min(...pts.map(q => Math.hypot(q.x - c.x, q.y - c.y)), Infinity);
                const covered = pts.filter((q, j) =>
                    q.x + labelWidth(words[j].t, smallScale) > c.x - 10 && q.x < c.x + bigW
                    && Math.abs(q.y - c.y) < bigHeight / 2 + 10).length;
                const score = Math.min(gap, minGap) - covered * 1000;
                if (score > bestScore) { best = c; bestScore = score; }
                if (covered === 0 && gap >= minGap) break;
            }
            pts.push(best);
        }
        return pts;
    }
}
