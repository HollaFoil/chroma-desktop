import QtQuick
import QtQuick.Layouts
import qs.Widgets
import qs.Popups
import qs.Services
PageBody {
    title: "Connections"
    headerItems: [ Pill { text: "󰒓  All connections…"; small: true; onClicked: { Overlays.settingsToggle(); Proc.sh("command -v nm-connection-editor >/dev/null && exec nm-connection-editor; exec kitty --title nmtui sh -c 'sleep 0.1; nmtui'") } } ]
    WiredSection { Layout.fillWidth: true; Layout.leftMargin: 6; Layout.rightMargin: 8 }
    Divider { Layout.fillWidth: true; visible: Net.wiredDevices.length > 0 && Net.hasTailscale }
    TailscaleSection { Layout.fillWidth: true; Layout.leftMargin: 6; Layout.rightMargin: 8 }
    Label { visible: Net.wiredDevices.length === 0 && !Net.hasTailscale; text: "Nothing here: no wired adapter, no tailscale."; dim: true; regular: true; leftPadding: 6 }
}
