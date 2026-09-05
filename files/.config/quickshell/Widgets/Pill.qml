import QtQuick
import qs.Theme

// A small rounded button with a text label; `on` paints it primary. The
// segmented control is a row of these.
Rectangle {
    id: root
    property string text: ""
    property bool on: false
    property bool small: false
    property int minWidth: small ? 76 : 0
    signal clicked()

    implicitWidth: Math.max(minWidth, label.implicitWidth + (small ? 18 : 20))
    implicitHeight: small ? 22 : label.implicitHeight + 6
    radius: Tokens.rSm
    color: !enabled ? Tokens.alpha(Colors.surfaceContainerHigh, 0.5)
         : on ? (ma.containsMouse ? Colors.primaryFixed : Colors.primary)
         : (ma.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh)
    Behavior on color { ColorAnimation { duration: Tokens.durFast } }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        size: Tokens.fontSizeSmall
        color: !root.enabled ? Colors.onSurfaceVariant : root.on ? Colors.onPrimary : Colors.onSurface
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
