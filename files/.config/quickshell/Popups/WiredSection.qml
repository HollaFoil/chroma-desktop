import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Read-only: each wired device with its state and address.
ColumnLayout {
    id: root
    spacing: Tokens.sp1
    visible: Net.wiredDevices.length > 0
    Repeater {
        model: Net.wiredDevices
        SectionHeader {
            id: row
            required property var modelData
            property string addr: ""
            glyph: "󰈀"; title: "Wired"
            inactive: !modelData.connected
            Layout.fillWidth: true
            function refresh() {
                if (!modelData.connected) { addr = ""; return }
                Proc.run(["nmcli", "-g", "IP4.ADDRESS", "device", "show", modelData.name], (c, out) => { addr = out.trim().split("\n")[0].split("/")[0] })
            }
            Component.onCompleted: refresh()
            Connections { target: row.modelData; function onConnectedChanged() { row.refresh() } }
            Label { text: modelData.name + " · " + (modelData.connected ? (row.addr || "connected") : "disconnected"); size: Tokens.fontSizeSmall; dim: true }
        }
    }
}
