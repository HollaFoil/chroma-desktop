import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Services

// One screen's widget layer: over the wallpaper, under every window. Only the
// widgets take input (the mask), so the rest of the desktop stays as it was;
// in edit mode the whole surface is live and the widgets grow handles.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property var widgets: Desktop.revision, Desktop.widgetsOn(modelData.name)
    visible: widgets.length > 0 || Desktop.editMode
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Desktop.editMode ? null : maskRegion
    Region { id: maskRegion; regions: frames.instances.map(f => f.region) }

    // edit mode: a faint grid and a hint
    Rectangle { anchors.fill: parent; visible: Desktop.editMode; color: Tokens.alpha(Colors.surface, 0.25) }
    Text {
        visible: Desktop.editMode
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 60 }
        text: "Editing widgets: drag to move, the corner to resize, × to remove · Settings › Widgets to finish"
        font.family: Tokens.fontFamily; font.bold: true; font.pixelSize: 14; color: Colors.surfaceFg
    }
    Variants {
        id: frames
        model: win.widgets
        WidgetFrame {
            screenName: win.modelData.name
            screenW: win.width; screenH: win.height
            parent: win.contentItem
        }
    }
}
