import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Wired, the radio (Wi-Fi and the hotspot that shares it), Bluetooth,
// Tailscale, and the way to everything else.
ColumnLayout {
    id: root
    spacing: Tokens.sp1
    WiredSection { Layout.fillWidth: true }
    Divider { Layout.fillWidth: true; visible: Net.wiredDevices.length > 0 }
    WifiSection { Layout.fillWidth: true }
    Divider { Layout.fillWidth: true; visible: Net.hasHotspot }
    HotspotSection { Layout.fillWidth: true }
    Divider { Layout.fillWidth: true; visible: Net.hasBluetooth }
    BluetoothSection { Layout.fillWidth: true }
    Divider { Layout.fillWidth: true; visible: Net.hasTailscale }
    TailscaleSection { Layout.fillWidth: true }
    Divider { Layout.fillWidth: true }
    ListRow {
        accent: true
        padY: 2
        onClicked: { Popups.close(); Proc.sh("command -v nm-connection-editor >/dev/null && exec nm-connection-editor; exec kitty --title nmtui sh -c 'sleep 0.1; nmtui'") }
        Label { text: "󰒓  All connections…"; size: Tokens.fontSizeSmall; dim: true }
    }
}
