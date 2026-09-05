import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.Theme
import qs.Widgets
import qs.Services

ColumnLayout {
    id: root
    property int listHeight: 240
    readonly property var dev: Net.wifiDevice
    readonly property bool ap: dev && dev.mode === WifiDeviceMode.Ap
    property var prompting: null       // the WifiNetwork awaiting a password
    property string status: ""
    property bool statusError: false
    spacing: Tokens.sp1
    visible: dev !== null

    Component.onCompleted: if (dev) dev.scannerEnabled = true
    Component.onDestruction: if (dev) dev.scannerEnabled = false

    SectionHeader {
        glyph: "󰖩"; title: "Wi-Fi"
        Layout.fillWidth: true
        Toggle { checked: Net.wifiEnabled; onToggled: v => Net.setWifiEnabled(v) }
    }
    StatusLine { Layout.fillWidth: true; text: !Net.wifiEnabled ? "Wi-Fi is off" : root.ap ? "hotspot is using the radio — turn it off to join a network" : "" }

    readonly property var nets: {
        if (!dev || !Net.wifiEnabled || ap) return []
        const list = dev.networks.values.filter(n => n.name && n.name.length)
        return list.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    }
    Scroller {
        Layout.fillWidth: true
        maxHeight: root.listHeight
        visible: Net.wifiEnabled && !root.ap
        Label { visible: root.nets.length === 0; text: "scanning…"; dim: true; regular: true; size: Tokens.fontSizeSmall; leftPadding: 6 }
        Repeater {
            model: root.nets
            ListRow {
                id: row
                required property var modelData
                readonly property var net: modelData
                Layout.fillWidth: true
                accent: false
                clickable: false
                padX: 6; padY: 2
                Connections {
                    target: row.net
                    function onConnectionFailed(reason) {
                        root.status = "connection failed (" + (reason === ConnectionFailReason.NoSecrets ? "wrong or missing password" : "reason " + reason) + ")"
                        root.statusError = true
                    }
                }
                Glyph { text: Net.wifiIcon(net.signalStrength); size: Tokens.fontSizeHeading; Layout.preferredWidth: 22; color: net.connected ? Colors.primary : Colors.surfaceVariantFg }
                Label { text: net.name; size: Tokens.fontSizeSmall; Layout.fillWidth: true; color: net.connected ? Colors.primary : Colors.surfaceFg }
                Glyph { text: "󰌾"; size: Tokens.fontSizeSmall; color: Colors.surfaceVariantFg; visible: Net.secured(net) }
                Label { text: net.stateChanging ? (net.connected ? "disconnecting…" : "connecting…") : ""; size: Tokens.fontSizeTiny; dim: true; visible: net.stateChanging }
                IconButton { glyph: "󰆴"; kind: "danger"; small: true; visible: net.known; onClicked: net.forget() }
                IconButton {
                    glyph: net.connected ? "󰌸" : "󰌷"; kind: "action"; small: true
                    onClicked: {
                        root.status = ""; root.statusError = false
                        if (net.connected) { Net.intend("wifi:" + net.name); net.disconnect(); return }
                        Net.intend("wifi:" + net.name)
                        if (net.known || !Net.secured(net)) { root.prompting = null; net.connect() }
                        else { root.prompting = net; pw.text = ""; pw.input.forceActiveFocus() }
                    }
                }
            }
        }
    }
    Revealer {
        open: root.prompting !== null
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Entry { id: pw; Layout.fillWidth: true; password: true; placeholder: "password for " + (root.prompting ? root.prompting.name : ""); onAccepted: root.join() }
            IconButton { glyph: "󰌷"; small: true; onClicked: root.join() }
            IconButton { glyph: "󰅖"; small: true; kind: "action"; onClicked: root.prompting = null }
        }
    }
    function join() {
        if (root.prompting && pw.text.length) { root.status = "connecting to " + root.prompting.name + "…"; root.prompting.connectWithPsk(pw.text); root.prompting = null }
    }
    StatusLine { Layout.fillWidth: true; text: root.status; error: root.statusError }
}
