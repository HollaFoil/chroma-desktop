import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.Theme
import qs.Widgets
import qs.Services

// Status notifier icons. Left click activates, right click opens the item's
// menu as one of our popups (no GTK popup to lag), middle click is the
// secondary action, scrolling scrolls. Hidden when empty or when the
// bar.tray pref is off.
Bubble {
    id: root
    corners: "mirror"
    interactive: false
    spacing: 8
    visible: SystemTray.items.values.length > 0 && Prefs.get("bar.tray", true)

    Repeater {
        model: SystemTray.items
        Item {
            id: cell
            required property var modelData
            implicitWidth: 18; implicitHeight: 18
            Layout.alignment: Qt.AlignVCenter
            Image {
                anchors.fill: parent
                source: cell.modelData.icon
                sourceSize.width: 18; sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
                opacity: ma.containsMouse ? 0.8 : 1
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const item = cell.modelData
                    if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && item.onlyMenu)) {
                        if (!item.hasMenu) return
                        const p = cell.mapToItem(null, 0, 0)
                        Popups.toggle("tray", root.bar.screen, p.x - 8, root.bar.width - p.x - cell.width - 8, "right", item)
                    } else if (mouse.button === Qt.MiddleButton) item.secondaryActivate()
                    else item.activate()
                }
                onWheel: wheel => cell.modelData.scroll(wheel.angleDelta.y > 0 ? 1 : -1, false)
            }
        }
    }
}
