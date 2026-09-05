import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Inline device picker: one row per node, a tick on the current one.
// `extraFirst` adds a leading "Default" row (name null).
ColumnLayout {
    id: root
    property var nodes: []
    property var current: null          // node.name, or null for the default row
    property string extraFirst: ""
    signal picked(var name)
    spacing: 2

    Repeater {
        model: (root.extraFirst ? [{ name: null, label: root.extraFirst }] : []).concat(root.nodes.map(n => ({ name: n.name, label: Audio.shortName(n) })))
        ListRow {
            required property var modelData
            Layout.fillWidth: true
            padY: 2
            active: false
            onClicked: root.picked(modelData.name)
            Glyph { text: modelData.name === root.current ? "󰄬" : " "; size: Tokens.fontSizeSmall; Layout.preferredWidth: 16 }
            Label { text: modelData.label; size: Tokens.fontSizeSmall; Layout.fillWidth: true; color: modelData.name === root.current ? Colors.primary : Colors.surfaceFg }
        }
    }
}
