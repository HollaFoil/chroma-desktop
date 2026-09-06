import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Widgets
import qs.Services

// The floating notifications on one screen: in the corner toast.position
// names (top-right by default, under the bar), newest nearest the bar's edge,
// sliding in from the side. Each toast keeps its own timeout from
// toast.timeout.normal / toast.timeout.low; critical ones never time out.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    property var allScreens: Quickshell.screens
    readonly property bool isFallback: allScreens.length > 0 && allScreens[0].name === modelData.name
    readonly property var mine: Notifs.popups.map(k => Notifs.entry(k)).filter(e => e && (e.screen === modelData.name || (isFallback && !allScreens.some(s => s.name === e.screen))))
    readonly property string position: Prefs.get("toast.position", "top-right")
    readonly property bool atTop: !position.startsWith("bottom")
    readonly property bool atLeft: position.endsWith("left")
    visible: mine.length > 0
    color: "transparent"
    anchors { top: win.atTop; bottom: !win.atTop; left: win.atLeft; right: !win.atLeft }
    margins { top: 12; bottom: 12; left: 16; right: 16 }
    implicitWidth: 420 + 16
    implicitHeight: Math.max(1, list.implicitHeight + 8)
    WlrLayershell.namespace: "qs-notif"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: list }

    ColumnLayout {
        id: list
        anchors.top: win.atTop ? parent.top : undefined
        anchors.bottom: win.atTop ? undefined : parent.bottom
        anchors.left: win.atLeft ? parent.left : undefined
        anchors.right: win.atLeft ? undefined : parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        width: 420
        spacing: 8
        Repeater {
            // at the bottom the column grows upward, so the newest goes last to stay nearest the edge
            model: win.atTop ? win.mine : win.mine.slice().reverse()
            Item {
                id: slot
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: card.implicitHeight
                readonly property int timeout: modelData.urgency === 2 ? 0 : modelData.urgency === 0 ? Prefs.get("toast.timeout.low", 5000) : Prefs.get("toast.timeout.normal", 10000)
                Timer { interval: slot.timeout; running: slot.timeout > 0 && !hover.containsMouse; onTriggered: Notifs.hideToast(slot.modelData.key) }
                HoverHandler { id: hover }
                NotificationCard {
                    id: card
                    width: parent.width
                    entry: slot.modelData
                    x: 0
                    opacity: 1
                    Component.onCompleted: { x = win.atLeft ? -440 : 440; opacity = 0; x = 0; opacity = 1 }
                    Behavior on x { NumberAnimation { duration: Tokens.durSlow; easing.type: Tokens.easing } }
                    Behavior on opacity { NumberAnimation { duration: Tokens.durNormal } }
                }
            }
        }
    }
}
