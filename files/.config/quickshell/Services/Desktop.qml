pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Desktop widgets: what exists (the catalogue), where each one sits on which
// screen, and edit mode, where widgets can be dragged and resized in place.
// The layout is yours: ~/.local/state/quickshell/layout.json, written here.
// Until that exists, Desktop/layout.json in the config is the starting point
// (read only; the first change is saved to the state file). Positions are
// pixels from the screen's top-left; a negative x or y counts from the right
// or bottom edge instead.
Singleton {
    id: root
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string layoutPath: stateDir + "/layout.json"
    readonly property string defaultPath: Quickshell.shellDir + "/Desktop/layout.json"
    property var layout: ({ screens: {} })       // { screens: { "DP-2": [ {id, type, x, y, w, h, options} ] } }
    property bool editMode: false
    property string menuScreen: ""                // the screen whose right-click menu is open ("" = none)
    property string selected: ""                  // widget id with the focus in arrange mode
    property int revision: 0
    onEditModeChanged: if (!editMode) selected = ""

    // type -> how it is offered and what it can be told. Option types: bool, text,
    // int (min/max, `zero` names the 0 value), apps (a list of desktop entry ids,
    // stored comma separated so a hand-edited layout.json still reads).
    readonly property var catalogue: ({
        Clock:      { name: "Clock",        glyph: "󰥔", w: 300, h: 150, options: [{ key: "seconds", label: "Show seconds", type: "bool", def: false }, { key: "date", label: "Show the date", type: "bool", def: true }] },
        Calendar:   { name: "Calendar",     glyph: "󰃭", w: 300, h: 290, options: [] },
        NowPlaying: { name: "Now playing",  glyph: "󰎈", w: 360, h: 150, options: [{ key: "controls", label: "Transport buttons", type: "bool", def: true }] },
        System:     { name: "System monitor", glyph: "󰍛", w: 300, h: 210, options: [{ key: "disk", label: "Disk to show", type: "text", def: "/" }] },
        Weather:    { name: "Weather",      glyph: "󰖕", w: 300, h: 150, options: [{ key: "location", label: "Location (blank = by IP)", type: "text", def: "" }] },
        Notes:      { name: "Notes",        glyph: "󰠮", w: 300, h: 220, options: [{ key: "title", label: "Title", type: "text", def: "Notes" }] },
        Shortcuts:  { name: "Shortcuts",    glyph: "󰀻", w: 300, h: 80,  options: [{ key: "apps", label: "Apps", type: "apps", def: "firefox, kitty, nemo" },
                                                                                 { key: "perRow", label: "Per row", type: "int", def: 0, min: 0, max: 12, zero: "one row" }] }
    })
    readonly property var types: Object.keys(catalogue)

    function take(text, what) {
        try { const j = JSON.parse(text); root.layout = j && j.screens ? j : { screens: {} }; root.revision++ }
        catch (e) { console.warn("Desktop: bad " + what + ": " + e) }
    }
    Component.onCompleted: Proc.run(["mkdir", "-p", stateDir], () => {})
    FileView {
        id: file
        path: root.layoutPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.take(text(), "layout.json")
        // no layout of your own yet: start from the one in the config
        onLoadFailed: defaults.reload()
    }
    FileView {
        id: defaults
        path: root.defaultPath
        printErrors: false
        onLoaded: root.take(text(), "Desktop/layout.json")
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

    // A new widget lands in a free spot on a coarse grid (or the centre when
    // asked), snapped, and becomes the selected one.
    function add(screenName, type, centre) {
        const cat = catalogue[type]; if (!cat) return
        const list = widgetsOn(screenName).slice()
        const id = type.toLowerCase() + "-" + Math.floor(Math.random() * 0xffffff).toString(16)
        let x = 48, y = 80
        if (centre) { x = 400; y = 300 }
        else {
            const taken = (px, py) => list.some(o => Math.abs(o.x - px) < 60 && Math.abs(o.y - py) < 60)
            for (let i = 0; i < 40 && taken(x, y); i++) { y += cat.h + 24; if (y > 800) { y = 80; x += cat.w + 24 } }
        }
        list.push({ id, type, x: Math.round(x / 8) * 8, y: Math.round(y / 8) * 8, w: cat.w, h: cat.h, options: {} })
        const l = JSON.parse(JSON.stringify(layout)); l.screens[screenName] = list; layout = l; save()
        selected = id
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
