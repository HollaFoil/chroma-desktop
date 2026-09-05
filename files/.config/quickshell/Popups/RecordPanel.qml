import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Theme
import qs.Widgets
import qs.Services

// Start or stop a recording: what to capture, which audio goes in.
ColumnLayout {
    id: root
    spacing: Tokens.sp2
    readonly property var monitors: Hyprland.monitors.values.map(m => m.name)

    SectionHeader {
        glyph: Recorder.recording ? "󰑊" : "󰻂"; title: Recorder.recording ? "Recording · " + Recorder.clock() : "Record"
        Layout.fillWidth: true
        Label { text: Recorder.backend; size: Tokens.fontSizeTiny; dim: true; regular: true }
    }

    // target
    RowLayout {
        Layout.fillWidth: true
        enabled: !Recorder.recording
        Label { text: "Capture"; size: Tokens.fontSizeSmall; Layout.preferredWidth: 90 }
        Segmented { model: ["Screen", "Window", "Region"]; current: ["screen", "window", "region"].indexOf(Recorder.target); onPicked: i => { Recorder.target = ["screen", "window", "region"][i]; Recorder.save() } }
    }
    // which screen: the monitors laid out as they stand, each a live preview
    ColumnLayout {
        Layout.fillWidth: true
        visible: Recorder.target === "screen"
        enabled: !Recorder.recording
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Screen"; size: Tokens.fontSizeSmall; Layout.preferredWidth: 90 }
            Pill { text: "focused monitor"; small: true; on: Recorder.screenName === ""; onClicked: { Recorder.screenName = ""; Recorder.save() } }
            Item { Layout.fillWidth: true }
        }
        Item {
            id: map
            readonly property var screens: Quickshell.screens
            readonly property real minX: Math.min(...screens.map(s => s.x))
            readonly property real minY: Math.min(...screens.map(s => s.y))
            readonly property real totalW: Math.max(...screens.map(s => s.x + s.width)) - minX
            readonly property real totalH: Math.max(...screens.map(s => s.y + s.height)) - minY
            readonly property real scale: Math.min(300 / Math.max(1, totalW), 120 / Math.max(1, totalH))
            Layout.leftMargin: 90
            Layout.preferredWidth: totalW * scale
            Layout.preferredHeight: totalH * scale
            Repeater {
                model: map.screens
                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool on: Recorder.screenName === modelData.name
                    readonly property bool focusedNow: Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === modelData.name
                    x: (modelData.x - map.minX) * map.scale + 2; y: (modelData.y - map.minY) * map.scale + 2
                    width: modelData.width * map.scale - 4; height: modelData.height * map.scale - 4
                    radius: Tokens.rXxs
                    color: Colors.surfaceContainerHigh
                    border.width: 2
                    border.color: on ? Colors.primary : tma.containsMouse ? Colors.tertiary : Tokens.alpha(Colors.outline, 0.4)
                    clip: true
                    ScreencopyView { anchors.fill: parent; anchors.margins: 2; captureSource: tile.modelData; live: true; opacity: 0.9 }
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 16; color: Tokens.alpha(Colors.surface, 0.75)
                        Label { anchors.centerIn: parent; text: tile.modelData.name + (tile.focusedNow ? "  ·  focused" : ""); size: Tokens.fontSizeMicro; color: tile.on ? Colors.primary : Colors.surfaceFg } }
                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Recorder.screenName = tile.modelData.name; Recorder.save() } }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        enabled: !Recorder.recording
        Label { text: "Frame rate"; size: Tokens.fontSizeSmall; Layout.preferredWidth: 90 }
        Segmented { model: ["30", "60"]; current: Recorder.fps === 30 ? 0 : 1; onPicked: i => { Recorder.fps = i === 0 ? 30 : 60; Recorder.save() } }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: Recorder.haveGsr
        enabled: !Recorder.recording
        Label { text: "Encoder"; size: Tokens.fontSizeSmall; Layout.preferredWidth: 90 }
        Segmented { model: ["GPU, CPU if it cannot", "CPU"]; current: Recorder.encoder === "cpu" ? 1 : 0; onPicked: i => { Recorder.encoder = i === 1 ? "cpu" : "auto"; Recorder.save() } }
    }
    Divider { Layout.fillWidth: true }

    // audio
    RowLayout {
        Layout.fillWidth: true
        enabled: !Recorder.recording
        Label { text: "Desktop audio"; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
        Toggle { checked: Recorder.desktopAudio; onToggled: v => { Recorder.desktopAudio = v; Recorder.save() } }
    }
    RowLayout {
        Layout.fillWidth: true
        enabled: !Recorder.recording
        Label { text: "Microphone"; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
        Toggle { checked: Recorder.micAudio; onToggled: v => { Recorder.micAudio = v; Recorder.save() } }
    }
    // per-app: only with gpu-screen-recorder
    ColumnLayout {
        Layout.fillWidth: true
        visible: Recorder.desktopAudio
        enabled: !Recorder.recording
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Apps"; size: Tokens.fontSizeSmall; Layout.preferredWidth: 90 }
            Segmented { enabled: Recorder.haveGsr; model: ["All", "Only", "All except"]; current: ["all", "only", "except"].indexOf(Recorder.appMode); onPicked: i => { Recorder.appMode = ["all", "only", "except"][i]; Recorder.save() } }
        }
        Label { visible: !Recorder.haveGsr; text: "install gpu-screen-recorder to include or exclude single apps"; size: Tokens.fontSizeTiny; dim: true; regular: true; leftPadding: 4; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Revealer {
            open: Recorder.haveGsr && Recorder.appMode !== "all"
            Layout.fillWidth: true
            Repeater {
                model: {
                    const names = Audio.streams.map(s => Audio.appKey(s)).filter((n, i, a) => n && a.indexOf(n) === i)
                    for (const a of Recorder.apps) if (names.indexOf(a) < 0) names.push(a)
                    return names.sort()
                }
                ListRow {
                    required property string modelData
                    Layout.fillWidth: true
                    accent: false
                    padY: 2
                    onClicked: Recorder.toggleApp(modelData)
                    Check { checked: Recorder.apps.indexOf(modelData) >= 0; onToggled: Recorder.toggleApp(modelData) }
                    Label { text: modelData; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
                    Label { text: Audio.streams.some(s => Audio.appKey(s) === modelData) ? "playing" : "not running"; size: Tokens.fontSizeTiny; dim: true }
                }
            }
            Label { visible: Audio.streams.length === 0 && Recorder.apps.length === 0; text: "nothing is playing right now"; size: Tokens.fontSizeTiny; dim: true; regular: true; leftPadding: 6 }
        }
    }
    Divider { Layout.fillWidth: true }
    StatusLine { Layout.fillWidth: true; text: Recorder.status; error: Recorder.status.indexOf("failed") >= 0 }
    RowLayout {
        Layout.fillWidth: true
        Label { text: Recorder.recording ? Recorder.outFile.split("/").pop() : "→ ~/Videos/Recordings"; size: Tokens.fontSizeTiny; dim: true; regular: true; Layout.fillWidth: true; elide: Text.ElideMiddle }
        Pill {
            text: Recorder.recording ? "󰓛  Stop" : Recorder.starting ? "picking…" : "󰑊  Start recording"
            on: !Recorder.recording
            enabled: !Recorder.starting
            onClicked: { if (Recorder.recording) Recorder.stop(); else { Popups.close(); Recorder.start() } }
        }
    }
}
