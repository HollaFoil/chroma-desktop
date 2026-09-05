import QtQuick
import qs.Theme

// A single-line text field: container-high ground, a primary ring on focus,
// primary caret. `password` hides the text.
Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool password: false
    signal accepted()
    signal editingFinished()

    implicitHeight: 26
    implicitWidth: 160
    radius: Tokens.rSm
    color: Colors.surfaceContainerHigh
    border.width: input.activeFocus ? 1 : 0
    border.color: Colors.primary
    Behavior on color { ColorAnimation { duration: Tokens.durSlow } }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        font.family: Tokens.fontFamily
        font.bold: true
        font.pixelSize: Tokens.fontSizeSmall
        color: Colors.surfaceFg
        selectionColor: Tokens.alpha(Colors.primary, Tokens.aSelection)
        selectedTextColor: Colors.surfaceFg
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        clip: true
        cursorDelegate: Rectangle { width: 1; color: Colors.primary; visible: input.cursorVisible }
        onAccepted: root.accepted()
        onEditingFinished: root.editingFinished()
    }
    Label {
        anchors.fill: input
        visible: input.text.length === 0
        text: root.placeholder
        dim: true
        regular: true
        size: Tokens.fontSizeSmall
    }
}
