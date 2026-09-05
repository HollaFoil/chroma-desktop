import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// What is connected, and a button to nwg-displays, which owns monitors.lua.
PageBody {
    id: root
    title: "Monitors"
    property var monitors: []
    headerItems: [ Pill { text: "Arrange in nwg-displays"; small: true; onClicked: { Overlays.settingsToggle(); Proc.detach(["nwg-displays"]) } } ]
    Component.onCompleted: Hypr.json(["monitors"], m => root.monitors = m || [])
    GridLayout {
        columns: 5
        rowSpacing: 6; columnSpacing: 18
        Layout.leftMargin: 6
        Repeater { model: ["output", "mode", "scale", "position", "workspace"]; Label { required property string modelData; text: modelData; size: Tokens.fontSizeSmall; color: Colors.primary } }
        Repeater {
            model: root.monitors.length * 5
            Label {
                required property int index
                readonly property var m: root.monitors[Math.floor(index / 5)]
                readonly property int col: index % 5
                text: col === 0 ? m.name + "  " + (m.description || "").slice(0, 28)
                    : col === 1 ? m.width + "x" + m.height + " @ " + Math.round(m.refreshRate) + " Hz"
                    : col === 2 ? String(m.scale)
                    : col === 3 ? m.x + ", " + m.y
                    : String((m.activeWorkspace || {}).name || "")
                size: col === 0 ? Tokens.fontSize : Tokens.fontSizeSmall
                dim: col !== 0
            }
        }
    }
    Label { text: "Layout, modes and scale are edited in nwg-displays, which writes ~/.config/hypr/monitors.lua."; size: Tokens.fontSizeTiny; dim: true; regular: true; leftPadding: 6; wrapMode: Text.Wrap; Layout.fillWidth: true }
}
