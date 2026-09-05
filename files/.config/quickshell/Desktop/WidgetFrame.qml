import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// The frosted card a widget lives in, placed from the layout; in edit mode
// it can be dragged, resized from the corner and removed.
Item {
    id: frame
    required property var modelData
    required property string screenName
    property real screenW: 0
    property real screenH: 0
    readonly property var w: modelData
    readonly property var region: Region { item: frame }

    x: w.x < 0 ? screenW + w.x - width : w.x
    y: w.y < 0 ? screenH + w.y - height : w.y
    width: Math.max(120, w.w)
    height: Math.max(60, w.h)

    Card {
        id: card
        anchors.fill: parent
        slanted: false
        alpha: Desktop.editMode ? 0.75 : 0.5
        padX: 18; padY: 16
        Loader {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            property var widget: frame.w
            property string screenName: frame.screenName
            source: "widgets/" + frame.w.type + "Widget.qml"
            onStatusChanged: if (status === Loader.Error) console.warn("Desktop: no widget of type " + frame.w.type)
        }
    }
    Rectangle { anchors.fill: parent; visible: Desktop.editMode; color: "transparent"; radius: Tokens.rCardA; border.width: 2; border.color: Tokens.alpha(Colors.primary, 0.7) }
    MouseArea {
        visible: Desktop.editMode
        anchors.fill: parent
        cursorShape: Qt.SizeAllCursor
        drag.target: frame
        drag.minimumX: 0; drag.minimumY: 0
        drag.maximumX: frame.screenW - frame.width; drag.maximumY: frame.screenH - frame.height
        onReleased: Desktop.update(frame.screenName, frame.w.id, { x: Math.round(frame.x), y: Math.round(frame.y) })
    }
    IconButton { visible: Desktop.editMode; anchors { top: parent.top; right: parent.right; margins: 6 } glyph: "󰅖"; kind: "danger"; small: true; onClicked: Desktop.remove(frame.screenName, frame.w.id) }
    Rectangle {
        visible: Desktop.editMode
        anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
        width: 18; height: 18; radius: 6; color: Colors.primary
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor
            property real sx: 0; property real sy: 0; property real sw: 0; property real sh: 0
            onPressed: mouse => { sx = mouse.x; sy = mouse.y; sw = frame.width; sh = frame.height }
            onPositionChanged: mouse => { if (pressed) { frame.width = Math.max(120, sw + mouse.x - sx); frame.height = Math.max(60, sh + mouse.y - sy) } }
            onReleased: Desktop.update(frame.screenName, frame.w.id, { w: Math.round(frame.width), h: Math.round(frame.height) })
        }
    }
}
