pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Desktop widgets: what exists (the catalogue), where each one sits on which
// screen (Desktop/layout.json, in the config so it travels with the
// dotfiles), and edit mode, where widgets can be dragged and resized in
// place. Positions are pixels from the screen's top-left; a negative x or y
// counts from the right or bottom edge instead.
Singleton {
    id: root
    readonly property string layoutPath: Quickshell.shellDir + "/Desktop/layout.json"
    property var layout: ({ screens: {} })       // { screens: { "DP-2": [ {id, type, x, y, w, h, options} ] } }
    property bool editMode: false
    property int revision: 0

    // type -> how it is offered and what it can be told
    readonly property var catalogue: ({
        Clock:      { name: "Clock",        glyph: "󰥔", w: 300, h: 150, options: [{ key: "seconds", label: "Show seconds", type: "bool", def: false }, { key: "date", label: "Show the date", type: "bool", def: true }] },
        Calendar:   { name: "Calendar",     glyph: "󰃭", w: 300, h: 290, options: [] },
        NowPlaying: { name: "Now playing",  glyph: "󰎈", w: 360, h: 150, options: [{ key: "controls", label: "Transport buttons", type: "bool", def: true }] },
        System:     { name: "System monitor", glyph: "󰍛", w: 300, h: 210, options: [{ key: "disk", label: "Disk to show", type: "text", def: "/" }] },
        Weather:    { name: "Weather",      glyph: "󰖕", w: 300, h: 150, options: [{ key: "location", label: "Location (blank = by IP)", type: "text", def: "" }] },
        Notes:      { name: "Notes",        glyph: "󰠮", w: 300, h: 220, options: [{ key: "title", label: "Title", type: "text", def: "Notes" }] },
        Shortcuts:  { name: "Shortcuts",    glyph: "󰀻", w: 300, h: 80,  options: [{ key: "apps", label: "Desktop entry ids, comma separated", type: "text", def: "firefox, kitty, nemo" }] }
    })
    readonly property var types: Object.keys(catalogue)

    FileView {
        id: file
        path: root.layoutPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const j = JSON.parse(text()); root.layout = j && j.screens ? j : { screens: {} }; root.revision++ } catch (e) { console.warn("Desktop: bad layout.json: " + e) } }
        onLoadFailed: { root.layout = { screens: {} }; root.revision++ }
    }
    function widgetsOn(screenName) { return (layout.screens || {})[screenName] || [] }
    function save() { root.revision++; file.setText(JSON.stringify(layout, null, 2) + "\n") }
    function option(w, key) {
        const cat = catalogue[w.type]
        if (w.options && w.options[key] !== undefined) return w.options[key]
        const o = cat ? cat.options.find(x => x.key === key) : null
        return o ? o.def : undefined
    }

    function add(screenName, type) {
        const cat = catalogue[type]; if (!cat) return
        const list = widgetsOn(screenName).slice()
        const id = type.toLowerCase() + "-" + Math.floor(Math.random() * 0xffffff).toString(16)
        list.push({ id, type, x: 40 + 30 * list.length, y: 80 + 30 * list.length, w: cat.w, h: cat.h, options: {} })
        const l = JSON.parse(JSON.stringify(layout)); l.screens[screenName] = list; layout = l; save()
    }
    function remove(screenName, id) {
        const l = JSON.parse(JSON.stringify(layout)); l.screens[screenName] = widgetsOn(screenName).filter(w => w.id !== id); layout = l; save()
    }
    function update(screenName, id, patch) {
        const l = JSON.parse(JSON.stringify(layout))
        l.screens[screenName] = widgetsOn(screenName).map(w => w.id === id ? Object.assign({}, w, patch) : w)
        layout = l; save()
    }
    function setOption(screenName, id, key, value) {
        const w = widgetsOn(screenName).find(x => x.id === id); if (!w) return
        const o = Object.assign({}, w.options || {}); o[key] = value
        update(screenName, id, { options: o })
    }
}
