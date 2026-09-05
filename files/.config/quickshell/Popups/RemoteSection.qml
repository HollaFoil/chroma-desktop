import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// VNC into this desktop over Tailscale (wayvnc). The address is the tailnet
// one only; the password is `remote-desktop password` in a terminal.
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
        Toggle { checked: Net.vncActive; onToggled: v => { root.status = v ? "starting…" : ""; root.statusError = false; Net.setVnc(v, err => { root.status = err || ""; root.statusError = !!err }) } }
    }
    Label { text: Net.vncActive ? "vnc://" + Net.vncAddress + ":" + Net.vncPort + "  ·  sharing " + Net.vncOutput : "off  ·  Tailscale only, user " + (Hypr.home.split("/").pop()) + ", password from `remote-desktop password`"
        size: Tokens.fontSizeSmall; dim: true; leftPadding: 34; wrapMode: Text.Wrap; Layout.fillWidth: true }
    RowLayout {
        Layout.leftMargin: 34
        Layout.fillWidth: true
        spacing: 8
        Label { text: "share"; size: Tokens.fontSizeTiny; dim: true }
        Segmented { model: root.monitors; current: root.monitors.indexOf(Net.vncOutput); onPicked: i => Net.setVncOutput(root.monitors[i]) }
        Item { Layout.fillWidth: true }
        Check { checked: Net.vncAutostart; text: "with the session"; onToggled: v => Net.setVncAutostart(v) }
    }
    StatusLine { Layout.fillWidth: true; text: root.status; error: root.statusError }
}
