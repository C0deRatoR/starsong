// Settings window. Every control writes straight to the saved settings, so changes show live.
import QtQuick
import QtQuick.Controls.Fusion
import QtQuick.Layouts

Window {
    id: win

    required property var cfg
    property color accent
    property var presetNames: []
    property var themeColors: [] // what the backdrop is using right now

    title: "Starsong"
    visible: false
    width: 540
    height: 780
    minimumWidth: 540
    maximumWidth: 540
    minimumHeight: 400
    color: "#141417"

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        // Dark palette for the Fusion controls; the album colour is the highlight.
        palette {
            window: "#141417"
            base: "#1d1d21"
            button: "#26262b"
            text: "#ece9e4"
            windowText: "#ece9e4"
            buttonText: "#ece9e4"
            placeholderText: "#77757a"
            highlight: win.accent
            highlightedText: "#141417"
            mid: "#2c2c31"
            dark: "#0e0e10"
        }

        ColumnLayout {
            width: parent.width
            spacing: 6

            ColumnLayout {
                Layout.margins: 24
                Layout.bottomMargin: 8
                spacing: 4
                Label { text: "Starsong"; font.pixelSize: 26; font.weight: Font.DemiBold }
                Label { text: "Changes apply as you make them."; opacity: 0.6 }
            }

            Section {
                title: "Lyrics"
                ChoiceRow {
                    label: "Style"
                    choices: [{ text: "Constellation", value: "constellation" }, { text: "Fisheye", value: "fisheye" }, { text: "Karaoke", value: "karaoke" }, { text: "3D wall", value: "wall" }, { text: "Off", value: "off" }]
                    value: win.cfg.style
                    onPicked: v => win.cfg.style = v
                }
                ChoiceRow {
                    label: "Font"
                    choices: ["Quicksand", "Segoe UI", "Bahnschrift", "Georgia", "Arial"].map(f => ({ text: f, value: f }))
                    value: win.cfg.fontFamily
                    onPicked: v => win.cfg.fontFamily = v
                }
                ChoiceRow {
                    label: "Weight"
                    choices: [{ text: "Light", value: 300 }, { text: "Regular", value: 400 }, { text: "Medium", value: 500 }, { text: "Semibold", value: 600 }, { text: "Bold", value: 700 }]
                    value: win.cfg.fontWeight
                    onPicked: v => win.cfg.fontWeight = v
                }
                SwitchRow { label: "Words pulse on the beat"; checked: win.cfg.beatWords; onToggled: v => win.cfg.beatWords = v }
                SliderRow {
                    label: "Lyrics timing"
                    from: -2000; to: 2000; stepSize: 50
                    value: win.cfg.lyricsOffsetMs
                    format: v => (v > 0 ? "+" : "") + (v / 1000).toFixed(2) + " s"
                    onMoved: v => win.cfg.lyricsOffsetMs = v
                }
                SliderRow {
                    label: "Text size"
                    from: 0.6; to: 1.6; stepSize: 0.05
                    value: win.cfg.textScale
                    onMoved: v => win.cfg.textScale = v
                }
            }

            Section {
                title: "Now playing"
                SwitchRow { label: "Show now playing"; checked: win.cfg.nowPlaying; onToggled: v => win.cfg.nowPlaying = v }
                ChoiceRow {
                    label: "Corner"
                    choices: [{ text: "Bottom left", value: "bottom-left" }, { text: "Bottom right", value: "bottom-right" }, { text: "Top left", value: "top-left" }, { text: "Top right", value: "top-right" }]
                    value: win.cfg.nowPlayingCorner
                    onPicked: v => win.cfg.nowPlayingCorner = v
                }
            }

            Section {
                title: "Stars"
                SliderRow {
                    label: "Star size"
                    from: 0.5; to: 2; stepSize: 0.05
                    value: win.cfg.starScale
                    onMoved: v => win.cfg.starScale = v
                }
                SliderRow {
                    label: "Halo"
                    from: 0; to: 2; stepSize: 0.05
                    value: win.cfg.haloStrength
                    onMoved: v => win.cfg.haloStrength = v
                }
                SwitchRow { label: "Twinkle"; checked: win.cfg.twinkle; onToggled: v => win.cfg.twinkle = v }
                SwitchRow { label: "Comets along new lines"; checked: win.cfg.comets; onToggled: v => win.cfg.comets = v }
                SwitchRow { label: "Ripple when a star appears"; checked: win.cfg.ripples; onToggled: v => win.cfg.ripples = v }
                SwitchRow { label: "Gentle float"; checked: win.cfg.drift; onToggled: v => win.cfg.drift = v }
            }

            Section {
                title: "Backdrop"
                SwitchRow { label: "Colour backdrop"; checked: win.cfg.backdrop; onToggled: v => win.cfg.backdrop = v }
                SliderRow {
                    label: "Darkness"
                    from: 0; to: 0.8; stepSize: 0.02
                    value: win.cfg.backdropDim
                    onMoved: v => win.cfg.backdropDim = v
                }
                SliderRow {
                    label: "Motion speed"
                    from: 0.25; to: 3; stepSize: 0.05
                    value: win.cfg.backdropSpeed
                    onMoved: v => win.cfg.backdropSpeed = v
                }
                SwitchRow { label: "Drifting dust"; checked: win.cfg.dust; onToggled: v => win.cfg.dust = v }
            }

            Section {
                title: "Edge glow"
                SwitchRow { label: "Edge glow"; checked: win.cfg.glow; onToggled: v => win.cfg.glow = v }
                SliderRow {
                    label: "Brightness"
                    from: 0.2; to: 2; stepSize: 0.05
                    value: win.cfg.glowIntensity
                    onMoved: v => win.cfg.glowIntensity = v
                }
                SliderRow {
                    label: "Thickness"
                    from: 10; to: 140; stepSize: 1
                    value: win.cfg.glowThickness
                    format: v => Math.round(v) + " px"
                    onMoved: v => win.cfg.glowThickness = v
                }
                SliderRow {
                    label: "Beat reaction"
                    from: 0; to: 2; stepSize: 0.05
                    value: win.cfg.glowBass
                    onMoved: v => win.cfg.glowBass = v
                }
                ChoiceRow {
                    label: "Motion"
                    choices: [
                        { text: "Still", value: "still" },
                        { text: "Waves", value: "waves" },
                        { text: "Orbit", value: "orbit" },
                        { text: "Twin orbit", value: "twin" },
                        { text: "Breathe", value: "breathe" },
                        { text: "Aurora", value: "aurora" },
                        { text: "Beat ripple", value: "ripple" },
                    ]
                    value: win.cfg.glowMode
                    onPicked: v => win.cfg.glowMode = v
                }
                SliderRow {
                    label: "Motion speed"
                    // Still has no motion; beat ripple follows the music.
                    enabled: !["still", "ripple"].includes(win.cfg.glowMode)
                    opacity: enabled ? 1 : 0.45
                    from: 0.25; to: 3; stepSize: 0.05
                    value: win.cfg.glowFlowSpeed
                    onMoved: v => win.cfg.glowFlowSpeed = v
                }
            }

            Section {
                title: "Colours"
                ChoiceRow {
                    label: "Colours"
                    choices: [{ text: "From the album", value: "album" }]
                        .concat(win.presetNames.map(n => ({ text: n[0].toUpperCase() + n.slice(1), value: n })))
                        .concat([{ text: "Cycle through presets", value: "cycle" }, { text: "My own", value: "custom" }])
                    value: win.cfg.colors
                    onPicked: v => win.cfg.colors = v
                }
                SliderRow {
                    label: "Switch every"
                    enabled: win.cfg.colors === "cycle"
                    opacity: enabled ? 1 : 0.45
                    from: 5; to: 600; stepSize: 5
                    value: win.cfg.cycleSeconds
                    format: v => v < 60 ? Math.round(v) + " s" : (v / 60).toFixed(v % 60 ? 1 : 0) + " min"
                    onMoved: v => win.cfg.cycleSeconds = v
                }
                // Swatches of the colours in use now, so presets can be compared at a glance.
                RowLayout {
                    Layout.preferredHeight: 40
                    spacing: 8
                    Repeater {
                        model: win.themeColors.slice(0, 5)
                        Rectangle {
                            required property color modelData
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: modelData
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }
                    }
                }
                ColorRow {
                    label: "First colour"
                    enabled: win.cfg.colors === "custom"
                    value: win.cfg.colorA
                    onPicked: v => win.cfg.colorA = v
                }
                ColorRow {
                    label: "Second colour"
                    enabled: win.cfg.colors === "custom"
                    value: win.cfg.colorB
                    onPicked: v => win.cfg.colorB = v
                }
            }

            Item { Layout.preferredHeight: 16 }
        }
    }

    // --- Building blocks ---------------------------------------------------------------------

    // A titled, rounded group of rows.
    component Section: ColumnLayout {
        id: section
        property string title
        default property alias rows: card.data
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        Layout.topMargin: 10
        spacing: 8

        Label {
            text: section.title.toUpperCase()
            font.pixelSize: 12
            font.letterSpacing: 1.2
            opacity: 0.55
            Layout.leftMargin: 4
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: card.implicitHeight + 12
            radius: 12
            color: "#1d1d21"
            ColumnLayout {
                id: card
                anchors.fill: parent
                anchors.margins: 6
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 0
            }
        }
    }

    component SliderRow: RowLayout {
        id: row
        property string label
        property alias from: slider.from
        property alias to: slider.to
        property alias stepSize: slider.stepSize
        property real value
        property var format: v => Math.round(v * 100) + "%"
        signal moved(real value)
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Label { text: row.label; Layout.fillWidth: true }
        Slider {
            id: slider
            Layout.preferredWidth: 190
            onMoved: row.moved(value)
            // Follow the saved value, except while being dragged.
            Binding on value { value: row.value; when: !slider.pressed }
        }
        Label { text: row.format(slider.value); opacity: 0.6; Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight }
    }

    component SwitchRow: RowLayout {
        id: row
        property string label
        property bool checked
        signal toggled(bool checked)
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Label { text: row.label; Layout.fillWidth: true }
        Switch {
            checked: row.checked
            onToggled: row.toggled(checked)
        }
    }

    component ChoiceRow: RowLayout {
        id: row
        property string label
        property var choices: [] // [{text, value}]
        property var value
        signal picked(var value)
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Label { text: row.label; Layout.fillWidth: true }
        ComboBox {
            Layout.preferredWidth: 200
            model: row.choices.map(c => c.text)
            currentIndex: Math.max(0, row.choices.findIndex(c => c.value === row.value))
            onActivated: index => row.picked(row.choices[index].value)
        }
    }

    component ColorRow: RowLayout {
        id: row
        property string label
        property string value
        signal picked(string value)
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        opacity: enabled ? 1 : 0.45
        Label { text: row.label; Layout.fillWidth: true }
        Rectangle {
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: row.value
            border.color: Qt.rgba(1, 1, 1, 0.2)
        }
        TextField {
            Layout.preferredWidth: 110
            text: row.value
            placeholderText: "#rrggbb"
            validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
            onEditingFinished: if (acceptableInput) row.picked(text)
        }
    }
}
