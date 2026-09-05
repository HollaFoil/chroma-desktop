import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// VNC into this desktop over Tailscale (wayvnc). On means on: now and from
// every login, until switched off. The password is `remote-desktop password`.
ColumnLayout {
    id: root
    property string status: ""
    property bool statusError: false
    readonly property var monitors: Hyprland.monitors.values.map(m => m.name)
    spacing: Tokens.sp1
    visible: Net.haveVnc
    SectionHeader {
        glyph: "󰢹"; title: "Remote desktop"
        Layout.fillWidth: true
        Toggle { checked: Net.vncOn; onToggled: v => { root.status = v ? "starting…" : ""; root.statusError = false; Net.setVnc(v, err => { root.status = err || ""; root.statusError = !!err }) } }
    }
    Label {
        text: Net.vncOn ? "vnc://" + Net.vncAddress + ":" + Net.vncPort + "  ·  user " + Hypr.home.split("/").pop() + "  ·  Tailscale only" : "off"
        size: Tokens.fontSizeSmall; dim: true; leftPadding: 34; wrapMode: Text.Wrap; Layout.fillWidth: true
    }
    RowLayout {
        Layout.leftMargin: 34
        Layout.fillWidth: true
        spacing: 8
        Label { text: "sharing"; size: Tokens.fontSizeTiny; dim: true }
        Segmented { model: root.monitors; current: root.monitors.indexOf(Net.vncOutput); onPicked: i => Net.setVncOutput(root.monitors[i]) }
    }
    StatusLine { Layout.fillWidth: true; text: root.status; error: root.statusError }
}
