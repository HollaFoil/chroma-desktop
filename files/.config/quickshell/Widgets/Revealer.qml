import QtQuick
import QtQuick.Layouts
import qs.Theme

// Slides its column open and shut (160 ms). Sits in a layout: the animated
// implicitHeight is what the parent measures.
Item {
    id: root
    property bool open: false
    property int spacing: Tokens.sp1
    default property alias content: col.data

    clip: true
    visible: open || implicitHeight > 0.5
    implicitWidth: col.implicitWidth
    implicitHeight: open ? col.implicitHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: Tokens.durReveal; easing.type: Tokens.easing } }
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Tokens.durReveal } }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: root.spacing
    }
}
