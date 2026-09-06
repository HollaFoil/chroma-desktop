import QtQuick
import QtQuick.Layouts
import qs.Widgets
import qs.Popups
import qs.Services
PageBody {
    title: "Wi-Fi"
    subtitle: "Networks in range and the hotspot"
    WifiSection { Layout.fillWidth: true; Layout.leftMargin: 6; Layout.rightMargin: 8; listHeight: 420 }
    Divider { Layout.fillWidth: true; visible: Net.hasHotspot }
    HotspotSection { Layout.fillWidth: true; Layout.leftMargin: 6; Layout.rightMargin: 8 }
    Label { visible: Net.wifiDevice === null; text: "No Wi-Fi adapter."; dim: true; regular: true; leftPadding: 6 }
}
