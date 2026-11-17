// One word that fills left to right with the accent colour while it is sung.
import QtQuick

Item {
    id: word

    property var line // {s, e, words: [{t, s}]}
    property int wordIndex
    property real posMs
    property bool live // only the line being sung fills
    property color fillColor
    property color baseColor: Qt.rgba(0.97, 0.95, 0.92, 0.45)
    property alias font: base.font
    readonly property int maxWordMs: 1500 // a word's fill never takes longer than this

    readonly property var entry: line ? line.words[wordIndex] : null
    readonly property real progress: {
        if (!live || !entry || posMs < entry.s)
            return 0;
        const next = wordIndex + 1 < line.words.length ? line.words[wordIndex + 1].s : line.e;
        const dur = Math.min(Math.max(next - entry.s, 1), maxWordMs);
        return Math.min((posMs - entry.s) / dur, 1);
    }

    width: base.implicitWidth
    height: base.implicitHeight

    Text {
        id: base
        text: word.entry ? word.entry.t : ""
        color: word.baseColor
    }
    Item {
        width: base.implicitWidth * word.progress
        height: base.implicitHeight
        clip: true
        Text {
            text: base.text
            font: base.font
            color: word.fillColor
        }
    }
}
