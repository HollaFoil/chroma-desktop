import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Picks the apps of a Shortcuts widget: the chosen ones as chips (‹ › reorder,
// × drops), a search line, and the apps that match, most used first, each a
// click away. Controlled: `ids` is the owner's list, `changed` hands back a
// new one.
ColumnLayout {
    id: root
    property var ids: []
    signal changed(var ids)
    spacing: 6
    readonly property var results: Apps.search(search.text, 8 + ids.length).filter(e => root.ids.indexOf(e.id) < 0).slice(0, 6)
    function move(i, d) { const l = ids.slice(); const t = l[i]; l[i] = l[i + d]; l[i + d] = t; changed(l) }
    function drop(i) { const l = ids.slice(); l.splice(i, 1); changed(l) }
    function add(id) { if (ids.indexOf(id) >= 0) return; changed(ids.concat([id])); search.text = "" }

    component ChipButton: Item {
        id: cb
        property string glyph: ""
        property bool danger: false
        signal clicked()
        implicitWidth: 16; implicitHeight: 16
        opacity: enabled ? 1 : 0.3
        Glyph { anchors.centerIn: parent; text: cb.glyph; size: 12; color: bma.containsMouse && cb.enabled ? (cb.danger ? Colors.error : Colors.primary) : Colors.surfaceVariantFg }
        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; enabled: cb.enabled; cursorShape: Qt.PointingHandCursor; onClicked: cb.clicked() }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: root.ids
            Rectangle {
                id: chip
                required property string modelData
                required property int index
                readonly property var entry: { DesktopEntries.applications.values; return DesktopEntries.byId(modelData) || DesktopEntries.heuristicLookup(modelData) }
                implicitWidth: row.implicitWidth + 12
                implicitHeight: 24
                radius: Tokens.rSm
                color: Colors.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
                RowLayout {
                    id: row
                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                    spacing: 4
                    Image { Layout.preferredWidth: 16; Layout.preferredHeight: 16; source: chip.entry ? Apps.icon(chip.entry) : ""; sourceSize.width: 32; sourceSize.height: 32; fillMode: Image.PreserveAspectFit; asynchronous: true }
                    Label { text: chip.entry ? chip.entry.name : chip.modelData; size: Tokens.fontSizeTiny; dim: !chip.entry; Layout.maximumWidth: 120 }
                    ChipButton { glyph: "󰅁"; enabled: chip.index > 0; onClicked: root.move(chip.index, -1) }
                    ChipButton { glyph: "󰅂"; enabled: chip.index < root.ids.length - 1; onClicked: root.move(chip.index, 1) }
                    ChipButton { glyph: "󰅖"; danger: true; onClicked: root.drop(chip.index) }
                }
            }
        }
        Label { visible: root.ids.length === 0; text: "no apps yet: pick them below"; size: Tokens.fontSizeTiny; dim: true; regular: true; height: 24 }
    }
    Entry {
        id: search
        Layout.fillWidth: true
        placeholder: "Search applications to add"
        onAccepted: if (root.results.length) root.add(root.results[0].id)
    }
    Scroller {
        Layout.fillWidth: true
        maxHeight: 6 * Tokens.rowHeight + 5 * spacing
        spacing: 1
        Repeater {
            model: root.results
            ListRow {
                id: r
                required property var modelData
                Layout.fillWidth: true
                padX: 6; padY: 3
                spacing: 8
                onClicked: root.add(modelData.id)
                Image { Layout.preferredWidth: 18; Layout.preferredHeight: 18; source: Apps.icon(r.modelData); sourceSize.width: 36; sourceSize.height: 36; fillMode: Image.PreserveAspectFit; asynchronous: true }
                Label { text: r.modelData.name; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
                Label { text: r.modelData.genericName || ""; size: Tokens.fontSizeTiny; dim: true; regular: true; visible: text.length > 0; Layout.maximumWidth: 140 }
                Glyph { text: "󰐕"; size: Tokens.fontSizeIconSmall; color: r.hovered ? Colors.primary : Colors.surfaceVariantFg }
            }
        }
        Label { visible: root.results.length === 0; text: search.text.length ? "nothing matches" : "every app is already here"; size: Tokens.fontSizeTiny; dim: true; regular: true; leftPadding: 6 }
    }
}
