// The Starsong window: the lyrics scene with its colour backdrop, now playing and edge glow.
// starsong.py passes in the settings and the live sources (null in demo mode).
import QtQuick
import QtQuick.Controls.Fusion

Window {
    id: win

    required property QtObject cfg // Settings.qml, loaded and saved by settings.py
    required property QtObject lyrics // Lyrics in starsong.py
    property QtObject media: null // MediaPlayer in media.py, not set in demo mode
    property QtObject audio: null // Audio in audio.py, not set in demo mode
    required property bool demo

    width: 1280
    height: 800
    minimumWidth: 480
    minimumHeight: 320
    visible: true
    title: core.player?.trackTitle ? `${core.player.trackTitle} · Starsong` : "Starsong"
    color: "black"

    Core {
        id: core
        cfg: win.cfg
        demo: win.demo
        livePlayer: win.media?.hasSession ? win.media : null
        albumColors: win.media?.albumColors ?? []
        onFetchRequested: (key, artist, title, length) => win.lyrics.fetch(key, artist, title, length)
    }
    Connections {
        target: win.lyrics
        function onLoaded(key, lines) { core.lyricsLoaded(key, lines); }
        function onFailed(key) { core.lyricsFailed(key); }
    }
    Connections {
        target: win.audio
        function onLevel(raw) { core.feedLevel(raw); }
    }
    Binding {
        when: win.audio !== null
        target: win.audio
        property: "active"
        value: core.playing
    }

    LyricsScene {
        anchors.fill: parent
        app: core
        forceBackdrop: true // no wallpaper behind a window
    }

    Glow {
        anchors.fill: parent
        cfg: win.cfg
        shown: core.playing && win.cfg.glow
        colorA: core.colorPalette[0]
        colorB: core.colorPalette[1]
        level: core.bass
        beats: core.beats
    }

    // Empty state: nothing to show until some app plays music.
    Column {
        anchors.centerIn: parent
        spacing: 10
        opacity: core.player ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Play music in any app"
            color: "#f7f2eb"
            font.family: core.fontFamily
            font.pixelSize: 30
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Spotify, your browser, or any player Windows shows in its media controls."
            color: "#a9a5ad"
            font.family: core.fontFamily
            font.pixelSize: 16
        }
    }

    // --- Controls: shown while the mouse moves, then out of the way -----------------------
    property bool controlsShown: true
    Timer { id: hideControls; interval: 2500; running: true; onTriggered: win.controlsShown = false }
    function poke() {
        controlsShown = true;
        hideControls.restart();
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: win.poke()
        cursorShape: win.controlsShown ? Qt.ArrowCursor : Qt.BlankCursor
    }

    Button {
        id: settingsButton
        anchors { top: parent.top; right: parent.right; margins: 16 }
        text: "Settings"
        Accessible.description: "Open settings (Ctrl+,)"
        opacity: win.controlsShown || hovered || settingsButton.activeFocus ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        onClicked: win.openSettings()
        palette { button: "#26262b"; buttonText: "#ece9e4" }
    }

    // A short message for keyboard actions, so they don't happen silently.
    Text {
        id: toast
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 24 }
        color: "#f7f2eb"
        font.family: core.fontFamily
        font.pixelSize: 18
        opacity: 0
        visible: opacity > 0
        SequentialAnimation on opacity {
            id: toastAnim
            running: false
            NumberAnimation { to: 0.9; duration: 150 }
            PauseAnimation { duration: 1300 }
            NumberAnimation { to: 0; duration: 500 }
        }
    }
    function say(message) {
        toast.text = message;
        toastAnim.restart();
    }

    function openSettings() {
        settingsWindow.show();
        settingsWindow.raise();
        settingsWindow.requestActivate();
    }
    function toggleFullScreen() {
        visibility = visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen;
    }
    function nudge(ms) {
        const offset = core.nudge(ms);
        say(`Lyrics ${offset > 0 ? "+" : ""}${(offset / 1000).toFixed(2)} s`);
    }
    function nextStyle() {
        const names = { constellation: "Constellation", fisheye: "Fisheye", karaoke: "Karaoke", wall: "3D wall", off: "Lyrics off" };
        say(names[core.next()]);
    }

    Shortcut { sequence: "F11"; onActivated: win.toggleFullScreen() }
    Shortcut { sequence: "Esc"; enabled: win.visibility === Window.FullScreen; onActivated: win.toggleFullScreen() }
    Shortcut { sequence: "["; onActivated: win.nudge(-100) }
    Shortcut { sequence: "]"; onActivated: win.nudge(100) }
    Shortcut { sequence: "N"; onActivated: win.nextStyle() }
    Shortcut { sequence: "Ctrl+,"; onActivated: win.openSettings() }

    SettingsWindow {
        id: settingsWindow
        transientParent: win
        cfg: win.cfg
        accent: core.colorPalette[0]
        themeColors: core.themeColors
        presetNames: core.presetNames
    }
}
