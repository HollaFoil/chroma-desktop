import QtQuick
import QtQuick.Layouts
import qs.Theme

// A frosted island: translucent surface that Hyprland blurs behind. Slanted
// (24/10/24/10) like the bar's bubbles; `mirrored` flips the pair, `slanted:
// false` gives an even 24 for the centred windows. Children land in a column.
Item {
    id: root
    property bool slanted: true
    property bool mirrored: false
    property real alpha: Tokens.aCard
    property int padX: Tokens.cardPadX
    property int padY: Tokens.cardPadY
    property int minWidth: 0
    property int spacing: Tokens.sp1
    default property alias content: body.data
    readonly property alias background: bg

    implicitWidth: Math.max(minWidth, body.implicitWidth + padX * 2)
    implicitHeight: body.implicitHeight + padY * 2

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Tokens.alpha(Colors.surface, root.alpha)
        topLeftRadius:     root.slanted ? (root.mirrored ? Tokens.rCardB : Tokens.rCardA) : Tokens.rCardA
        topRightRadius:    root.slanted ? (root.mirrored ? Tokens.rCardA : Tokens.rCardB) : Tokens.rCardA
        bottomRightRadius: root.slanted ? (root.mirrored ? Tokens.rCardB : Tokens.rCardA) : Tokens.rCardA
        bottomLeftRadius:  root.slanted ? (root.mirrored ? Tokens.rCardA : Tokens.rCardB) : Tokens.rCardA
        Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.leftMargin: root.padX
        anchors.rightMargin: root.padX
        anchors.topMargin: root.padY
        anchors.bottomMargin: root.padY
        spacing: root.spacing
    }
}
