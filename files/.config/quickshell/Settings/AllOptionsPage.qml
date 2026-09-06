import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Every option Hyprland reports, one folded Group per config section. The
// window's search opens the sections that have a match and lists only the
// matching rows; rows are built when a section first opens.
PageBody {
    id: root
    title: "All options"
    subtitle: "Every option Hyprland reports, grouped by section; use the search box to find one"
    readonly property var hidden: ["debug", "opengl", "quirks", "experimental"]
    Component.onCompleted: Hypr.loadSchema(false)
    status: Hypr.schemaLoaded ? "" : "reading options…"
    // every option name is a search word for this page, built or not
    Connections { target: Hypr; function onSchemaChanged2() { root.addWords(Object.keys(Hypr.schema).map(n => n + " " + n.replace(/[:_.]/g, " ")).join(" ")) } }
    onGroupsChanged: if (Hypr.schemaLoaded && root.words.length === 0) root.addWords(Object.keys(Hypr.schema).map(n => n + " " + n.replace(/[:_.]/g, " ")).join(" "))

    readonly property var groups: {
        const g = {}
        for (const name of Object.keys(Hypr.schema)) {
            const head = name.split(":")[0]
            if (hidden.indexOf(head) >= 0) continue
            (g[head] = g[head] || []).push(name)
        }
        return Object.keys(g).sort().map(k => ({ name: k, options: g[k].sort() }))
    }
    function hits(names) {
        if (!SettingsSearch.active) return names
        return names.filter(n => SettingsSearch.matches(n.replace(/[:_.]/g, " ") + " " + n + " " + ((Hypr.schema[n] || {}).description || "")))
    }

    Repeater {
        model: root.groups
        Group {
            id: sec
            required property var modelData
            readonly property var shown: root.hits(modelData.options)
            title: modelData.name
            hint: modelData.options.length + " options"
            advanced: true
            open: false
            visible: shown.length > 0
            Repeater {
                model: sec.expanded ? sec.shown : []
                OptionRow { required property var modelData; name: modelData }
            }
        }
    }
}
