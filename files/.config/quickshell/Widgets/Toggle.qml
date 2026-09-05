import QtQuick
import qs.Theme

// A switch. Controlled: the owner binds `checked` to its model and reacts to
// `toggled`, so the knob never disagrees with the thing it stands for.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 20
    radius: Tokens.rPill
    color: !enabled ? Tokens.alpha(Colors.surfaceContainerHighest, 0.5)
         : checked ? Colors.primary : Colors.surfaceContainerHighest
    Behavior on color { ColorAnimation { duration: Tokens.durFast } }

    Rectangle {
        width: 16; height: 16; radius: 8; y: 2
        x: root.checked ? root.width - 18 : 2
        color: root.checked ? Colors.onPrimary : Colors.onSurfaceVariant
        Behavior on x { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easing } }
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
