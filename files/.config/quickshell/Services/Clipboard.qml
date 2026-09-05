pragma Singleton
import QtQuick
import Quickshell

// cliphist: the history, copying an entry back, deleting one, wiping all.
Singleton {
    id: root
    property var entries: []      // { id, line, text, image: bool, summary }
    function refresh() {
        Proc.run(["cliphist", "list"], (code, out) => {
            entries = out.split("\n").filter(l => l.length).map(l => {
                const tab = l.indexOf("\t")
                const id = l.slice(0, tab), text = l.slice(tab + 1)
                const m = text.match(/^\[\[ binary data (.*?) (\w+) (\d+x\d+) \]\]$/)
                return { id, line: l, text, image: !!m, summary: m ? ("󰋩 " + m[2] + " " + m[3] + " · " + m[1]) : text.replace(/\s+/g, " ").trim() }
            })
        })
    }
    function copy(entry) { Proc.sh("cliphist decode " + entry.id + " | wl-copy") }
    function remove(entry, cb) { Proc.run(["sh", "-c", "printf '%s\\n' \"$QS_LINE\" | cliphist delete"], () => { refresh(); if (cb) cb() }, { QS_LINE: entry.line }) }
    function wipe(cb) { Proc.run(["cliphist", "wipe"], () => { refresh(); if (cb) cb() }) }
}
