import QtQuick
import qs.Theme

// A hairline with breathing room above and below.
Item {
    property int gap: Tokens.sp2
    implicitHeight: 1 + gap * 2
    implicitWidth: 40
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 1
        color: Tokens.alpha(Colors.outlineVariant, Tokens.aDivider)
        Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
    }
}
