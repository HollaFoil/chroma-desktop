import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Services

// The session lock: one surface per screen, all showing the same state.
WlSessionLock {
    id: lock
    locked: Lock.locked
    WlSessionLockSurface {
        color: Colors.surface
        LockScreen {
            anchors.fill: parent
            model: Lock
            wallpaper: Colors.wallpaper
            greeter: false
        }
    }
}
