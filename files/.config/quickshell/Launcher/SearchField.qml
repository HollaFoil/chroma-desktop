import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets

// The launcher's search line: a glyph, a big text field, no chrome.
RowLayout {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: "Search"
    property string glyph: "󰍉"
    signal accepted()
    signal up()
    signal down()
    signal deleteRequested(int modifiers)
    spacing: 12
    Glyph { text: root.glyph; size: 20; Layout.leftMargin: 6 }
    TextInput {
        id: input
        Layout.fillWidth: true
        font.family: Tokens.fontFamily
        font.bold: true
        font.pixelSize: 15
        color: Colors.surfaceFg
        selectionColor: Tokens.alpha(Colors.primary, Tokens.aSelection)
        selectedTextColor: Colors.surfaceFg
        cursorDelegate: Rectangle { width: 2; color: Colors.primary; visible: input.cursorVisible }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) { root.down(); event.accepted = true }
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) { root.up(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.accepted(); event.accepted = true }
            else if (event.key === Qt.Key_Delete && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) { root.deleteRequested(event.modifiers); event.accepted = true }
        }
        Label { anchors.fill: parent; visible: !input.text.length; text: root.placeholder; dim: true; regular: true; size: 15 }
    }
}
