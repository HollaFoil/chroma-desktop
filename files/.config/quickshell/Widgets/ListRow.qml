import QtQuick
import QtQuick.Layouts
import qs.Theme

// A hoverable row that lays its children out horizontally. `accent` hovers in
// primary (a thing you pick), otherwise in a whisper of on_surface (a thing
// with its own controls). Child buttons get the click first.
Rectangle {
    id: root
    property bool accent: true
    property bool active: false
    property bool clickable: true
    property int padX: Tokens.sp2
    property int padY: 3
    property int spacing: Tokens.sp2
    default property alias content: row.data
    readonly property bool hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()

    radius: Tokens.rXs
    implicitHeight: Math.max(Tokens.rowHeight, row.implicitHeight + padY * 2)
    implicitWidth: row.implicitWidth + padX * 2
    color: active ? Tokens.alpha(Colors.primary, Tokens.aActive)
         : (hovered && clickable) ? (accent ? Tokens.alpha(Colors.primary, Tokens.aHover)
                                            : Tokens.alpha(Colors.onSurface, Tokens.aSubtle))
         : "transparent"
    Behavior on color { ColorAnimation { duration: Tokens.durFast } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: root.padX
        anchors.rightMargin: root.padX
        anchors.topMargin: root.padY
        anchors.bottomMargin: root.padY
        spacing: root.spacing
    }
}
