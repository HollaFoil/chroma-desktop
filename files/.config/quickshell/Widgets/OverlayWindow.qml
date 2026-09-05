import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme

// A transparent surface over one whole output that hosts one card. The card
// hangs under the bar at an anchor (placement "bar") or floats in the middle
// (placement "center"). Click on the backdrop or Escape (on release, so the
// window underneath does not see a phantom press) closes it. Hyprland blurs
// the card only: the qs-overlay layer rule ignores fully transparent pixels.
PanelWindow {
    id: root
    property string placement: "bar"          // bar | center
    property string side: "right"             // bar placement: left | right | center
    property real anchorX: 0                  // left edge of the opener (screen coords)
    property real anchorRight: 0              // gap from the opener's right edge to the screen's right edge
    property int edgeMargin: 8
    property bool open: false
    // A page recording a keybind sets this to a function(event) -> bool; while
    // set, every key press goes to it and nothing else (Escape cancels the
    // recording instead of closing the window).
    property var keyGrab: null
    property alias card: cardSlot
    default property alias content: cardSlot.data
    signal dismissed()

    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Asks the owner to close: `open` is usually a binding, so the owner flips it in onDismissed.
    function close() { dismissed() }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        property bool escDown: false
        Keys.onPressed: event => {
            if (root.keyGrab) { event.accepted = !!root.keyGrab(event); return }
            if (event.key === Qt.Key_Escape) { escDown = true; event.accepted = true }
        }
        Keys.onReleased: event => {
            if (root.keyGrab) { event.accepted = true; return }
            if (event.key === Qt.Key_Escape && escDown) { escDown = false; root.close(); event.accepted = true }
        }

        // swallows clicks inside the card so the backdrop never sees them
        MouseArea {
            x: cardSlot.x; y: cardSlot.y; width: cardSlot.width; height: cardSlot.height
            acceptedButtons: Qt.AllButtons
        }
        Item {
            id: cardSlot
            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
            width: implicitWidth
            height: implicitHeight
            x: {
                if (root.placement === "center" || root.side === "center") return Math.round((root.width - width) / 2)
                if (root.side === "left") return Math.max(root.edgeMargin, Math.min(root.anchorX, root.width - width - root.edgeMargin))
                return Math.max(root.edgeMargin, root.width - root.anchorRight - width)
            }
            y: root.placement === "center" ? Math.round((root.height - height) / 2) : Tokens.barHeight + Tokens.popupGap
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.97
            transformOrigin: root.placement === "center" ? Item.Center : Item.Top
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easing } }
        }
    }
}
