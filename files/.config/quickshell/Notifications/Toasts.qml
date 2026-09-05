import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Widgets
import qs.Services

// The floating notifications on one screen: top-right under the bar, newest
// on top, sliding in from the edge. Each toast keeps its own timeout.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    property var allScreens: Quickshell.screens
    readonly property bool isFallback: allScreens.length > 0 && allScreens[0].name === modelData.name
    readonly property var mine: Notifs.popups.map(k => Notifs.entry(k)).filter(e => e && (e.screen === modelData.name || (isFallback && !allScreens.some(s => s.name === e.screen))))
    visible: mine.length > 0
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: 12; right: 16 }
    implicitWidth: 420 + 16
    implicitHeight: Math.max(1, list.implicitHeight + 8)
    WlrLayershell.namespace: "qs-notif"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: list }

    ColumnLayout {
        id: list
        anchors { top: parent.top; right: parent.right; rightMargin: 8 }
        width: 420
        spacing: 8
        Repeater {
            model: win.mine
            Item {
                id: slot
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: card.implicitHeight
                readonly property int timeout: modelData.urgency === 2 ? 0 : modelData.urgency === 0 ? 5000 : 10000
                Timer { interval: slot.timeout; running: slot.timeout > 0 && !hover.containsMouse; onTriggered: Notifs.hideToast(slot.modelData.key) }
                HoverHandler { id: hover }
                NotificationCard {
                    id: card
                    width: parent.width
                    entry: slot.modelData
                    x: 0
                    opacity: 1
                    Component.onCompleted: { x = 440; opacity = 0; x = 0; opacity = 1 }
                    Behavior on x { NumberAnimation { duration: Tokens.durSlow; easing.type: Tokens.easing } }
                    Behavior on opacity { NumberAnimation { duration: Tokens.durNormal } }
                }
            }
        }
    }
}
