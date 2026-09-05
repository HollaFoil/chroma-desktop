import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services
// A row of app icons; ids are desktop entry names (firefox, kitty, org.gnome.Nautilus...).
RowLayout {
    id: root
    readonly property var w: parent.widget
    readonly property var ids: String(Desktop.option(w, "apps") || "").split(",").map(s => s.trim()).filter(s => s)
    spacing: 8
    Repeater {
        model: root.ids
        Rectangle {
            id: cell
            required property string modelData
            readonly property var entry: DesktopEntries.byId(modelData) || DesktopEntries.heuristicLookup(modelData)
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 1
            radius: Tokens.rMd
            color: ma.containsMouse ? Tokens.alpha(Colors.primary, Tokens.aHover) : "transparent"
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            Image { anchors.centerIn: parent; width: Math.min(40, parent.height - 12); height: width; source: cell.entry ? Apps.icon(cell.entry) : ""; sourceSize.width: 64; sourceSize.height: 64; fillMode: Image.PreserveAspectFit; asynchronous: true }
            Label { anchors.centerIn: parent; visible: !cell.entry; text: cell.modelData; size: Tokens.fontSizeTiny; dim: true }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (cell.entry) Apps.launch(cell.entry) }
        }
    }
    Label { visible: root.ids.length === 0; text: "set the apps in Settings › Widgets"; dim: true; regular: true; size: Tokens.fontSizeSmall }
}
