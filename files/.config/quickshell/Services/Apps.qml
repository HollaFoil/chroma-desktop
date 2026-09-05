pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Desktop entries with a launch count per app, so the launcher can put what
// you actually use first (~/.local/state/quickshell/launcher.json).
Singleton {
    id: root
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/launcher.json"
    property var counts: ({})
    FileView { id: state; path: root.statePath; printErrors: false; onLoaded: { try { root.counts = JSON.parse(text()).counts || {} } catch (e) {} } }

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay && e.name)

    function score(e, q) {
        const name = e.name.toLowerCase()
        if (name === q) return 0
        if (name.startsWith(q)) return 1
        if (name.split(/[\s\-_]+/).some(w => w.startsWith(q))) return 2
        if (name.indexOf(q) >= 0) return 3
        const extra = [(e.genericName || ""), (e.comment || "")].concat(e.keywords || []).join(" ").toLowerCase()
        if (extra.indexOf(q) >= 0) return 4
        // subsequence: "ffx" -> firefox
        let i = 0
        for (const ch of name) { if (ch === q[i]) i++; if (i === q.length) return 5 }
        return -1
    }
    function search(query, limit) {
        const q = query.trim().toLowerCase()
        let list
        if (!q) list = all.map(e => ({ e, s: 0 }))
        else list = all.map(e => ({ e, s: score(e, q) })).filter(x => x.s >= 0)
        list.sort((a, b) => (a.s - b.s) || ((counts[b.e.id] || 0) - (counts[a.e.id] || 0)) || a.e.name.localeCompare(b.e.name))
        return list.slice(0, limit).map(x => x.e)
    }
    function launch(e) {
        const c = Object.assign({}, counts); c[e.id] = (c[e.id] || 0) + 1; counts = c
        state.setText(JSON.stringify({ counts: c }, null, 1))
        e.execute()
    }
    function icon(e) { return e.icon ? Quickshell.iconPath(e.icon, true) : "" }
}
