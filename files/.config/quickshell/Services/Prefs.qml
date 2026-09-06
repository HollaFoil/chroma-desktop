pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's own preferences (what the Settings window changes about the bar,
// clock, notifications and OSD), one flat JSON object at
// ~/.local/state/quickshell/prefs.json. Readers bind through get(): it touches
// `data`, so a binding follows every change.
Singleton {
    id: root
    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/prefs.json"
    property var data: ({})

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()) || {} } catch (e) { root.data = {} } }
    }
    function get(key, fallback) { const v = data[key]; return v === undefined ? fallback : v }
    function set(key, value) {
        const d = Object.assign({}, data)
        if (value === undefined || value === null) delete d[key]; else d[key] = value
        data = d
        file.setText(JSON.stringify(d, Object.keys(d).sort(), 2) + "\n")
    }
    function toggle(key, fallback) { set(key, !get(key, fallback)) }
}
