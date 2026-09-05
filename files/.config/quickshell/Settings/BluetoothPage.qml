import QtQuick
import QtQuick.Layouts
import qs.Widgets
import qs.Popups
import qs.Services
// Discovery runs while the page is on screen.
PageBody {
    id: root
    title: "Bluetooth"
    onVisibleChanged: { if (visible && Net.adapter && Net.adapter.enabled) Net.scan(); else if (!visible) Net.stopScan() }
    BluetoothSection { Layout.fillWidth: true; Layout.leftMargin: 6; Layout.rightMargin: 8; listHeight: 440 }
    Label { visible: !Net.hasBluetooth; text: "No Bluetooth adapter."; dim: true; regular: true; leftPadding: 6 }
}
