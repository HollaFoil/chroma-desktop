import QtQuick
import QtQuick.Layouts
import qs.Theme

// A column that grows to its content until `maxHeight`, then scrolls, with a
// 4 px bar on the right that only appears when there is something to scroll.
Item {
    id: root
    property int maxHeight: 240
    property int spacing: 2
    default property alias content: col.data
    readonly property bool overflowing: col.implicitHeight > height + 0.5

    implicitHeight: Math.min(maxHeight, col.implicitHeight)
    implicitWidth: col.implicitWidth

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: col
            width: flick.width - (root.overflowing ? 8 : 0)
            spacing: root.spacing
        }
    }
    Rectangle {
        visible: root.overflowing
        anchors.right: parent.right
        width: 4
        radius: 2
        height: Math.max(20, root.height * root.height / Math.max(1, col.implicitHeight))
        y: col.implicitHeight > 0 ? flick.contentY / col.implicitHeight * root.height : 0
        color: Tokens.alpha(Colors.outline, 0.5)
    }
}
