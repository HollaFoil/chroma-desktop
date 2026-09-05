import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// A tray item's DBus menu, drawn by us. Submenus push onto a stack with a
// back row on top.
ColumnLayout {
    id: root
    readonly property var item: Popups.extra
    property var stack: item ? [item.menu] : []
    spacing: 2
    QsMenuOpener { id: opener; menu: root.stack.length ? root.stack[root.stack.length - 1] : null }

    Label { text: root.item ? (root.item.title || root.item.id) : ""; size: Tokens.fontSizeSmall; dim: true; leftPadding: 10; bottomPadding: 2 }
    ListRow {
        visible: root.stack.length > 1
        Layout.fillWidth: true
        padX: 10; padY: 4
        onClicked: root.stack = root.stack.slice(0, -1)
        Glyph { text: "󰅁"; size: Tokens.fontSizeSmall; color: Colors.surfaceVariantFg; Layout.preferredWidth: 18 }
        Label { text: "Back"; size: Tokens.fontSizeSmall; dim: true }
    }
    Repeater {
        model: opener.children
        Item {
            id: entry
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: modelData.isSeparator ? sep.implicitHeight : row.implicitHeight
            Divider { id: sep; visible: entry.modelData.isSeparator; width: parent.width; gap: 3 }
            ListRow {
                id: row
                visible: !entry.modelData.isSeparator
                width: parent.width
                padX: 10; padY: 5
                enabled: entry.modelData.enabled
                opacity: enabled ? 1 : 0.5
                onClicked: {
                    if (entry.modelData.hasChildren) root.stack = root.stack.concat([entry.modelData])
                    else { entry.modelData.triggered(); Popups.close() }
                }
                Glyph {
                    visible: entry.modelData.buttonType !== QsMenuButtonType.None
                    text: entry.modelData.checkState === Qt.Checked ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "󰐾" : "󰄬") : (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "󰄰" : " ")
                    size: Tokens.fontSizeSmall
                    Layout.preferredWidth: 16
                }
                Image { visible: entry.modelData.icon !== ""; source: entry.modelData.icon; sourceSize.width: 16; sourceSize.height: 16; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                Label { text: entry.modelData.text; size: Tokens.fontSizeSmall; Layout.fillWidth: true; Layout.minimumWidth: 140 }
                Glyph { text: "󰅂"; size: Tokens.fontSizeSmall; color: Colors.surfaceVariantFg; visible: entry.modelData.hasChildren }
            }
        }
    }
}
