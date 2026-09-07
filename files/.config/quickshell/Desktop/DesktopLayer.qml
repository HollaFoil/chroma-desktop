import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Widgets
import qs.Services

// One screen's widget layer: over the wallpaper, under every window. The bare
// desktop is ours to click: a right click opens a small menu (arrange, add,
// wallpaper, settings). In arrange mode a palette of live previews appears at
// the top, the widgets grow handles, and everything snaps to an 8 px grid.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property var widgets: Desktop.revision, Desktop.widgetsOn(modelData.name)
    visible: true
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // one menu at a time, across screens: a press on any bare desktop closes it
    readonly property bool menuOpen: Desktop.menuScreen === modelData.name
    property real menuX: 0
    property real menuY: 0

    // the bare desktop: right click for the menu, left click closes it / deselects
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) { win.menuX = mouse.x; win.menuY = mouse.y; Desktop.menuScreen = win.modelData.name }
            else { Desktop.menuScreen = ""; Desktop.selected = "" }
        }
    }
    Rectangle { anchors.fill: parent; visible: Desktop.editMode; color: Tokens.alpha(Colors.surface, 0.2) }

    // keyed by id: a moved, resized or reconfigured widget keeps its frame (and
    // its open options card); only adding and removing creates and destroys
    Variants {
        id: frames
        model: win.widgets.map(w => w.id)
        WidgetFrame {
            screenName: win.modelData.name
            screenW: win.width; screenH: win.height
            parent: win.contentItem
        }
    }

    WidgetPalette {
        visible: Desktop.editMode
        screenName: win.modelData.name
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: Tokens.barHeight + 24 }
    }

    DesktopMenu {
        visible: win.menuOpen
        screenName: win.modelData.name
        x: Math.min(win.menuX, win.width - width - 8)
        y: Math.min(win.menuY, win.height - height - 8)
        onClosed: Desktop.menuScreen = ""
    }
}
