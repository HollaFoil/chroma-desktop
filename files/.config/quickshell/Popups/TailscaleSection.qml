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
    visible: Net.hasTailscale
    Component.onCompleted: Net.refreshTailscale()
    SectionHeader {
        glyph: "󰖂"; title: "Tailscale"
        Layout.fillWidth: true
        Toggle { checked: Net.tailscaleUp; onToggled: v => { root.status = v ? "tailscale up…" : "tailscale down…"; root.statusError = false; Net.setTailscale(v, err => { root.status = err || ""; root.statusError = !!err }) } }
    }
    Label { text: Net.tailscaleDetail; size: Tokens.fontSizeSmall; dim: true; leftPadding: 34; elide: Text.ElideRight; Layout.fillWidth: true }
    StatusLine { Layout.fillWidth: true; text: root.status; error: root.statusError }
}
