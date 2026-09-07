import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services
// App icons in a grid; ids are desktop entry names (firefox, kitty,
// org.gnome.Nautilus...). `perRow` wraps the row (0 = everything in one).
GridLayout {
    id: root
    readonly property var w: parent.widget
    readonly property var ids: String(Desktop.option(w, "apps") || "").split(",").map(s => s.trim()).filter(s => s)
    readonly property int perRow: Number(Desktop.option(w, "perRow")) || 0
    columns: Math.max(1, perRow > 0 ? Math.min(perRow, ids.length) : ids.length)
    rowSpacing: 4
    columnSpacing: 8
    Repeater {
        model: root.ids
        Rectangle {
            id: cell
            required property string modelData
            // The desktop entries are scanned after the shell is up, so at login
            // this runs before they exist. Reading `values` here makes it run
            // again when they arrive; before that the icons stayed blank (only the
            // ids showed) until a resize rebuilt the widget.
            readonly property var entry: { DesktopEntries.applications.values; return DesktopEntries.byId(modelData) || DesktopEntries.heuristicLookup(modelData) }
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 1; Layout.preferredHeight: 1
            radius: Tokens.rMd
            color: ma.containsMouse ? Tokens.alpha(Colors.primary, Tokens.aHover) : "transparent"
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            Image { anchors.centerIn: parent; width: Math.max(16, Math.min(40, parent.height - 12, parent.width - 12)); height: width; source: cell.entry ? Apps.icon(cell.entry) : ""; sourceSize.width: 64; sourceSize.height: 64; fillMode: Image.PreserveAspectFit; asynchronous: true }
            Label { anchors.centerIn: parent; visible: !cell.entry; text: cell.modelData; size: Tokens.fontSizeTiny; dim: true }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (cell.entry) Apps.launch(cell.entry) }
        }
    }
    Label { visible: root.ids.length === 0; text: "no apps yet: 󰒓 in arrange mode, or Settings › Widgets"; dim: true; regular: true; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
}
