import QtQuick
import qs.Theme

// A small checkbox with a caption (the "sheet" tick on a keybind row).
Item {
    id: root
    property bool checked: false
    property string text: ""
    signal toggled(bool value)
    implicitWidth: row.implicitWidth
    implicitHeight: 18

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Rectangle {
            width: 16; height: 16; radius: Tokens.rXxs
            anchors.verticalCenter: parent.verticalCenter
            color: root.checked ? Colors.primary : Colors.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            Glyph { anchors.centerIn: parent; text: "󰄬"; size: 11; color: Colors.primaryFg; visible: root.checked }
        }
        Label { text: root.text; size: Tokens.fontSizeTiny; dim: true; anchors.verticalCenter: parent.verticalCenter; visible: root.text.length > 0 }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
}
