import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// The frosted card a widget lives in, placed from the layout. In arrange mode:
// drag to move, the corner to resize (both snap to 8 px), 󰒓 for the widget's
// options right there, × to remove. The frame is keyed by the widget's id and
// reads its entry live, so editing an option leaves the frame (and the open
// options card) in place.
Item {
    id: frame
    required property string modelData        // the widget's id
    required property string screenName
    property real screenW: 0
    property real screenH: 0
    readonly property var w: Desktop.revision, (Desktop.widgetsOn(screenName).find(o => o.id === modelData) || ({ id: modelData, type: "", x: 0, y: 0, w: 120, h: 60, options: {} }))
    readonly property bool selected: Desktop.selected === w.id
    readonly property var cat: Desktop.catalogue[w.type] || { name: w.type, options: [] }
    property bool optionsOpen: false

    function placeX() { return w.x < 0 ? screenW + w.x - width : w.x }
    function placeY() { return w.y < 0 ? screenH + w.y - height : w.y }
    function sizeW() { return Math.max(120, w.w) }
    function sizeH() { return Math.max(60, w.h) }
    x: placeX()
    y: placeY()
    width: sizeW()
    height: sizeH()
    // a drag or resize writes x/y/width/height directly, which drops the
    // bindings; once the layout has the new values, follow it again
    function rebind() { x = Qt.binding(placeX); y = Qt.binding(placeY); width = Qt.binding(sizeW); height = Qt.binding(sizeH) }
    z: selected ? 10 : 1
    function snap(v) { return Math.round(v / 8) * 8 }

    Card {
        anchors.fill: parent
        slanted: false
        alpha: Desktop.editMode ? 0.75 : 0.5
        padX: 18; padY: 16
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            property var widget: frame.w
            property string screenName: frame.screenName
            source: frame.w.type ? "widgets/" + frame.w.type + "Widget.qml" : ""
            onStatusChanged: if (status === Loader.Error) console.warn("Desktop: no widget of type " + frame.w.type)
        }
    }

    // ── arrange mode ──
    Rectangle {
        anchors.fill: parent; visible: Desktop.editMode; color: "transparent"; radius: Tokens.rCardA
        border.width: 2; border.color: frame.selected ? Colors.primary : Tokens.alpha(Colors.primary, 0.45)
    }
    MouseArea {
        visible: Desktop.editMode
        anchors.fill: parent
        cursorShape: Qt.SizeAllCursor
        drag.target: frame
        drag.minimumX: 0; drag.minimumY: 0
        drag.maximumX: frame.screenW - frame.width; drag.maximumY: frame.screenH - frame.height
        onPressed: Desktop.selected = frame.w.id
        onReleased: { Desktop.update(frame.screenName, frame.w.id, { x: frame.snap(frame.x), y: frame.snap(frame.y) }); frame.rebind() }
    }
    RowLayout {
        visible: Desktop.editMode
        anchors { top: parent.top; right: parent.right; margins: 6 }
        spacing: 2
        IconButton { glyph: "󰒓"; kind: "action"; small: true; visible: frame.cat.options.length > 0; busy: frame.optionsOpen; onClicked: { frame.optionsOpen = !frame.optionsOpen; Desktop.selected = frame.w.id } }
        IconButton { glyph: "󰅖"; kind: "danger"; small: true; onClicked: Desktop.remove(frame.screenName, frame.w.id) }
    }
    Rectangle {
        visible: Desktop.editMode
        anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
        width: 18; height: 18; radius: 6; color: Colors.primary
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor
            property real sx: 0; property real sy: 0; property real sw: 0; property real sh: 0
            onPressed: mouse => { sx = mouse.x; sy = mouse.y; sw = frame.width; sh = frame.height; Desktop.selected = frame.w.id }
            onPositionChanged: mouse => { if (pressed) { frame.width = Math.max(120, sw + mouse.x - sx); frame.height = Math.max(60, sh + mouse.y - sy) } }
            onReleased: { Desktop.update(frame.screenName, frame.w.id, { w: frame.snap(frame.width), h: frame.snap(frame.height) }); frame.rebind() }
        }
    }
    // the options, right under the widget
    Card {
        visible: Desktop.editMode && frame.optionsOpen && frame.cat.options.length > 0
        anchors { top: parent.bottom; left: parent.left; topMargin: 8 }
        slanted: false
        alpha: 0.9
        padX: 14; padY: 10
        minWidth: Math.max(frame.width, frame.cat.options.some(o => o.type === "apps") ? 360 : 0)
        spacing: 8
        Label { text: frame.cat.name + " options"; size: Tokens.fontSizeSmall; color: Colors.primary }
        Repeater {
            model: frame.cat.options
            OptionEditor {
                required property var modelData
                option: modelData
                widget: frame.w
                screenName: frame.screenName
                Layout.fillWidth: true
            }
        }
    }
    onSelectedChanged: if (!selected) optionsOpen = false
}
