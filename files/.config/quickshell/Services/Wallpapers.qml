pragma Singleton
import QtQuick
import Quickshell

// The wallpaper library (~/Pictures/Wallpapers, recursive), the one on screen
// (awww query) and the way to apply one (setwall, which recolours everything).
Singleton {
    id: root
    readonly property string dir: Quickshell.env("WALLSTRIP_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property string setwall: Quickshell.env("HOME") + "/.local/bin/setwall"
    property var files: []
    property string current: ""

    function refresh() {
        Proc.run(["find", dir, "-type", "f", "!", "-name", ".*"], (code, out) => {
            files = out.split("\n").filter(l => l.length > 0).sort()
        })
        Proc.run(["awww", "query"], (code, out) => {
            const m = out.match(/image: (.*)/)
            if (m) current = m[1].trim()
        })
    }
    function apply(path) {
        current = path
        Proc.detach([setwall, path])
    }
    function stem(path) { return path.split("/").pop().replace(/\.[^.]+$/, "") }
    Component.onCompleted: refresh()
}
