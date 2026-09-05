import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// One island on the bar. `corners` picks the slant: "mirror" (10/24/10/24,
// the default for standalone bubbles), "slant" (24/10/24/10), "capLeft" and
// "capRight" (the ends of a slanted group), "capLeftM"/"capRightM" (a mirrored group), "launcher" and "clock" (into the screen
// corners), "round" (16), "none".
Item {
    id: root
    property var bar: null
    property string corners: "mirror"
    property int padL: Tokens.barBubblePadX
    property int padR: Tokens.barBubblePadX
    property int marginL: Tokens.barBubbleGap
    property int marginR: 0
    property bool fullHeight: false
    property bool interactive: true
    property int spacing: 0
    readonly property bool hovered: ma.containsMouse
    readonly property alias rect: rect
    default property alias content: row.data
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int delta)

    Layout.fillHeight: true
    implicitWidth: rect.implicitWidth + marginL + marginR

    function radii(c) {
        switch (c) {
        case "slant":    return [24, 10, 24, 10]
        case "mirror":   return [10, 24, 10, 24]
        case "capLeft":  return [24, 0, 0, 10]      // group ends, slant orientation
        case "capRight": return [0, 10, 24, 0]
        case "capLeftM":  return [10, 0, 0, 24]     // group ends, mirror orientation
        case "capRightM": return [0, 24, 10, 0]
        case "launcher": return [0, 0, Tokens.barCornerRadius, 0]
        case "clock":    return [0, 0, 0, Tokens.barCornerRadius]
        case "round":    return [16, 16, 16, 16]
        default:         return [0, 0, 0, 0]
        }
    }
    readonly property var r: radii(corners)

    // Where this bubble sits on its screen, for a popup to hang under it.
    function anchorInfo() {
        const p = rect.mapToItem(null, 0, 0)
        return { x: p.x, right: (bar ? bar.width : 0) - p.x - rect.width }
    }
    function openPopup(name, side, extra) {
        const a = anchorInfo()
        Popups.toggle(name, bar.screen, a.x, a.right, side ?? "right", extra ?? null)
    }

    RoundedRect {
        id: rect
        x: root.marginL
        y: root.fullHeight ? 0 : Tokens.barBubbleMargin
        height: root.height - (root.fullHeight ? 0 : Tokens.barBubbleMargin * 2)
        width: implicitWidth
        implicitWidth: row.implicitWidth + root.padL + root.padR
        color: Colors.surface
        topLeft: root.r[0]
        topRight: root.r[1]
        bottomRight: root.r[2]
        bottomLeft: root.r[3]
        Behavior on color { ColorAnimation { duration: Tokens.durSlow } }

        MouseArea {
            id: ma
            anchors.fill: parent
            enabled: root.interactive
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) root.rightClicked()
                else if (mouse.button === Qt.MiddleButton) root.middleClicked()
                else root.clicked()
            }
            onWheel: wheel => root.scrolled(wheel.angleDelta.y)
        }
        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: root.padL
            anchors.rightMargin: root.padR
            spacing: root.spacing
        }
    }
}
