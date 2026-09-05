import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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
    RowLayout {
        Layout.fillWidth: true
        visible: Recorder.target === "screen"
        enabled: !Recorder.recording
        Label { text: "Screen"; size: Tokens.fontSizeSmall; Layout.preferredWidth: 90 }
        Segmented { model: ["focused"].concat(root.monitors); current: Recorder.screenName ? root.monitors.indexOf(Recorder.screenName) + 1 : 0
            onPicked: i => { Recorder.screenName = i === 0 ? "" : root.monitors[i - 1]; Recorder.save() } }
    }
    RowLayout {
        Layout.fillWidth: true
        enabled: !Recorder.recording
        Label { text: "Frame rate"; size: Tokens.fontSizeSmall; Layout.preferredWidth: 90 }
        Segmented { model: ["30", "60"]; current: Recorder.fps === 30 ? 0 : 1; onPicked: i => { Recorder.fps = i === 0 ? 30 : 60; Recorder.save() } }
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
