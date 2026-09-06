import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets

// The settings window's combo box: a button showing the current choice that
// drops the list (DropdownLayer) under itself. `model` is a list of
// { text, value, hint } or plain strings. Lists over eight items get a filter.
Rectangle {
    id: root
    property var model: []
    property var current: undefined
    property string placeholder: "Choose…"
    property int minWidth: 120
    property var searchable: undefined
    signal picked(var value)

    readonly property var items: model.map(m => (typeof m === "object" && m !== null) ? m : ({ text: String(m), value: m }))
    readonly property var currentItem: items.find(it => it.value === current) ?? null

    implicitWidth: Math.max(minWidth, label.implicitWidth + 34)
    implicitHeight: 24
    radius: Tokens.rSm
    color: !enabled ? Tokens.alpha(Colors.surfaceContainerHigh, 0.5) : (ma.containsMouse || Dropdown.anchor === root) ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
    border.width: Dropdown.anchor === root ? 1 : 0
    border.color: Colors.primary
    Behavior on color { ColorAnimation { duration: Tokens.durFast } }

    Label {
        id: label
        anchors { left: parent.left; right: chevron.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 4 }
        // a value that is not in the list (hand-edited, or a theme that went away) is shown as it is
        readonly property bool custom: !root.currentItem && root.current !== undefined && root.current !== null && String(root.current) !== ""
        text: root.currentItem ? root.currentItem.text : custom ? String(root.current) : root.placeholder
        size: Tokens.fontSizeSmall
        dim: !root.currentItem && !custom
        regular: !root.currentItem && !custom
        color: !root.enabled ? Colors.surfaceVariantFg : (root.currentItem || custom) ? Colors.surfaceFg : Colors.surfaceVariantFg
        Layout.maximumWidth: 260
    }
    Glyph { id: chevron; anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter } text: "󰅀"; size: Tokens.fontSizeIconSmall; color: Colors.surfaceVariantFg }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Dropdown.open && Dropdown.anchor === root) { Dropdown.close(); return }
            Dropdown.show(root, root.items, root.current, v => root.picked(v), root.searchable)
        }
    }
}
