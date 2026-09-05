import QtQuick
import QtQuick.Layouts
import qs.Theme

// One key combination on a keybind row: the combo (click to re-record),
// an optional parameter caption ("1-0"), and an x to drop it. `capturing`
// pulses it while a new combination is awaited.
Rectangle {
    id: root
    property string text: ""
    property string param: ""
    property bool capturing: false
    property bool removable: true
    signal clicked()
    signal pressedWith(int button, int modifiers)
    signal removed()

    implicitWidth: row.implicitWidth + 2
    implicitHeight: 22
    radius: Tokens.rXs
    color: capturing ? Tokens.alpha(Colors.primary, Tokens.aActive) : Colors.surfaceContainerHigh
    Behavior on color { ColorAnimation { duration: Tokens.durFast } }
    SequentialAnimation on opacity {
        running: root.capturing
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
    }
    onCapturingChanged: if (!capturing) opacity = 1

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Rectangle {
            implicitWidth: keyLabel.implicitWidth + 12
            implicitHeight: 20
            radius: Tokens.rXs
            color: "transparent"
            Label {
                id: keyLabel
                anchors.centerIn: parent
                text: root.text
                size: Tokens.fontSizeSmall
                color: (root.capturing || ma.containsMouse) ? Colors.primary : Colors.surfaceFg
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => {
                    if (root.capturing && !(mouse.button === Qt.LeftButton && mouse.modifiers === Qt.NoModifier)) {
                        root.pressedWith(mouse.button, mouse.modifiers)
                        mouse.accepted = true
                    }
                }
                onClicked: mouse => { if (mouse.button === Qt.LeftButton) root.clicked() }
            }
        }
        Label { text: root.param; size: Tokens.fontSizeSmall; dim: true; visible: root.param.length > 0 }
        IconButton { glyph: "󰅖"; kind: "action"; small: true; visible: root.removable; implicitWidth: 18; onClicked: root.removed() }
    }
}
