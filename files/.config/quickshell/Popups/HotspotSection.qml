import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

ColumnLayout {
    id: root
    property string status: ""
    property bool statusError: false
    spacing: Tokens.sp1
    visible: Net.hasHotspot
    SectionHeader {
        glyph: "󱜠"; title: "Hotspot"
        Layout.fillWidth: true
        Toggle { checked: Net.hotspotActive; onToggled: v => { root.status = v ? "starting hotspot…" : ""; root.statusError = false; Net.setHotspot(v, err => { root.status = err || ""; root.statusError = !!err }) } }
    }
    Label { text: Net.hotspotSsid + (Net.hotspotActive ? " · " + Net.hotspotClients + (Net.hotspotClients === 1 ? " client" : " clients") : " · off"); size: Tokens.fontSizeSmall; dim: true; leftPadding: 34 }
    StatusLine { Layout.fillWidth: true; text: root.status; error: root.statusError }
}
