pragma Singleton
import QtQuick
import Quickshell

// Which bar popup is open, on which screen, anchored where. Bar modules call
// toggle(); every screen's PopupHost shows the panel when `screen` is its own.
Singleton {
    id: root
    property string current: ""
    property var screen: null
    property string side: "right"
    property real anchorX: 0
    property real anchorRight: 0
    property var extra: null
    signal closed(string name)

    function toggle(name, screen, x, right, side, extra) {
        if (current === name && root.screen === screen) { close(); return }
        open(name, screen, x, right, side, extra)
    }
    function open(name, screen, x, right, side, extra) {
        const was = current
        root.screen = screen
        anchorX = x ?? 0
        anchorRight = right ?? 0
        root.side = side ?? "right"
        root.extra = extra ?? null
        current = name
        if (was !== "" && was !== name) closed(was)
    }
    function close() {
        const n = current
        if (n === "") return
        current = ""
        extra = null
        closed(n)
    }
}
