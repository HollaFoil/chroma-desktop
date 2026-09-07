import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Theme

// A transparent surface over one whole output that hosts one card. The card
// hangs under the bar at an anchor (placement "bar") or floats in the middle
// (placement "center"). A click anywhere outside the card - the backdrop, or
// another monitor - or Escape (on release, so the window underneath does not
// see a phantom press) closes it. Hyprland blurs the card only: the
// qs-overlay layer rule ignores fully transparent pixels.
//
// Keyboard: on demand, held by a Hyprland focus grab while open. It used to be
// Exclusive, which Hyprland honours by forcing pointer focus back onto the
// exclusive surface whenever the cursor is anywhere else - so on another
// monitor a click went nowhere and the popup stayed. With the grab the window
// keeps the keyboard while the pointer roams, and the first click outside it
// clears the grab (Hyprland swallows that click) and closes the popup.
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
    property bool anyKeyCloses: false        // the cheatsheet: any key (on release) closes
    property alias card: cardSlot
    default property alias content: cardSlot.data
    signal dismissed()

    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    readonly property bool hasKeyboard: scope.Window.active

    // Asks the owner to close: `open` is usually a binding, so the owner flips it in onDismissed.
    function close() { dismissed() }

    // `active` goes false by itself whenever the compositor drops the grab (a
    // click outside, or the window hiding), so it is driven by hand, not bound.
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: {
            root.close()
            // the owner may keep the window (Settings closes only its dropdown first): grab again
            if (root.open) Qt.callLater(() => { if (root.open && !grab.active) grab.active = true })
        }
    }
    onOpenChanged: grab.active = open

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
            if (event.key === Qt.Key_Escape || root.anyKeyCloses) { escDown = true; event.accepted = true }
        }
        Keys.onReleased: event => {
            if (root.keyGrab) { event.accepted = true; return }
            if ((event.key === Qt.Key_Escape || root.anyKeyCloses) && escDown) { escDown = false; root.close(); event.accepted = true }
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
