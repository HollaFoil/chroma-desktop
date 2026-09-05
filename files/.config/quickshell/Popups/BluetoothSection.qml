import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.Theme
import qs.Widgets
import qs.Services

ColumnLayout {
    id: root
    property int listHeight: 200
    property bool scanWhileVisible: false
    readonly property var adapter: Net.adapter
    property string status: ""
    property bool statusError: false
    spacing: Tokens.sp1
    visible: Net.hasBluetooth

    Component.onCompleted: if (scanWhileVisible && adapter && adapter.enabled) Net.scan()
    Component.onDestruction: if (scanWhileVisible) Net.stopScan()

    SectionHeader {
        glyph: "󰂯"; title: "Bluetooth"
        Layout.fillWidth: true
        IconButton { glyph: "󰑐"; kind: "action"; small: true; busy: root.adapter && root.adapter.discovering; enabled: root.adapter && root.adapter.enabled; onClicked: Net.scan() }
        Toggle { checked: root.adapter ? root.adapter.enabled : false; onToggled: v => { if (root.adapter) root.adapter.enabled = v } }
    }
    readonly property var devices: {
        if (!adapter || !adapter.enabled) return []
        const list = adapter.devices.values.filter(d => d.paired || d.connected || (adapter.discovering && d.name))
        return list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    }
    Scroller {
        Layout.fillWidth: true
        maxHeight: root.listHeight
        Label { visible: root.adapter && !root.adapter.enabled; text: "Bluetooth is off"; dim: true; regular: true; size: Tokens.fontSizeSmall; leftPadding: 6 }
        Label { visible: root.adapter && root.adapter.enabled && root.devices.length === 0; text: "no paired devices — Scan to find one"; dim: true; regular: true; size: Tokens.fontSizeSmall; leftPadding: 6 }
        Repeater {
            model: root.devices
            ListRow {
                id: row
                required property var modelData
                readonly property var d: modelData
                Layout.fillWidth: true
                accent: false
                clickable: false
                padX: 6; padY: 2
                Connections {
                    target: row.d
                    function onPairedChanged() { if (row.d.paired && row.pairingHere) { row.d.trusted = true; row.d.connect(); row.pairingHere = false } }
                }
                property bool pairingHere: false
                Glyph { text: Net.btIcon(d.icon); size: Tokens.fontSizeHeading; Layout.preferredWidth: 22; color: d.connected ? Colors.primary : Colors.surfaceVariantFg }
                Label { text: d.name || d.address; size: Tokens.fontSizeSmall; Layout.fillWidth: true; color: d.connected ? Colors.primary : Colors.surfaceFg }
                Label { text: Math.round(d.battery * 100) + "%"; size: Tokens.fontSizeTiny; dim: true; visible: d.connected && d.batteryAvailable }
                Label { text: d.pairing ? "pairing…" : (d.state === BluetoothDeviceState.Connecting ? "connecting…" : d.state === BluetoothDeviceState.Disconnecting ? "disconnecting…" : ""); size: Tokens.fontSizeTiny; dim: true; visible: text.length > 0 }
                IconButton { glyph: "󰆴"; kind: "danger"; small: true; visible: d.paired; onClicked: d.forget() }
                IconButton {
                    glyph: d.connected ? "󰌸" : d.paired ? "󰌷" : "󰐕"; kind: "action"; small: true
                    onClicked: {
                        if (d.connected) d.disconnect()
                        else if (d.paired) d.connect()
                        else { row.pairingHere = true; d.pair() }
                    }
                }
            }
        }
    }
    StatusLine { Layout.fillWidth: true; text: root.status; error: root.statusError }
}
