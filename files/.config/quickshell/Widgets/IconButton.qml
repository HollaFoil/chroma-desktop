import QtQuick
import qs.Theme

// A glyph that acts. kind: "default" (primary), "muted" (variant, static),
// "action" (quiet until hovered, then primary), "danger" (quiet, then error).
// `busy` pulses it (a scan in progress, a key being recorded).
Rectangle {
    id: root
    property string glyph: ""
    property string kind: "default"
    property bool small: false
    property bool busy: false
    readonly property bool hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()

    implicitWidth: Math.max(small ? 24 : 30, g.implicitWidth + (small ? 12 : 16))
    implicitHeight: g.implicitHeight + (small ? 4 : 8)
    radius: Tokens.rSm
    color: hovered && enabled
         ? (kind === "danger" ? Tokens.alpha(Colors.error, Tokens.aHover) : Tokens.alpha(Colors.primary, Tokens.aHover))
         : "transparent"
    Behavior on color { ColorAnimation { duration: Tokens.durFast } }

    Glyph {
        id: g
        anchors.centerIn: parent
        text: root.glyph
        size: root.small ? Tokens.fontSizeIconSmall : Tokens.fontSizeIcon
        color: !root.enabled ? Colors.surfaceVariantFg
             : root.busy || root.kind === "default" ? Colors.primary
             : root.kind === "muted" ? Colors.surfaceVariantFg
             : root.kind === "action" ? (root.hovered ? Colors.primary : Colors.surfaceVariantFg)
             : (root.hovered ? Colors.error : Colors.surfaceVariantFg)
        SequentialAnimation {
            running: root.busy
            loops: Animation.Infinite
            NumberAnimation { target: g; property: "opacity"; to: 0.3; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { target: g; property: "opacity"; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) g.opacity = 1
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
