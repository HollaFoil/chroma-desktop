import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// A page that is Groups of Hyprland options. `spec` is a flat list: a
// { group: "Title", hint, advanced } item starts a group, strings are option
// names inside it, and { row: "name", label, hint } names an option with its
// own wording. Unknown names are skipped, so a page keeps working across
// Hyprland versions. `extra` Groups (built by the page) go on top.
PageBody {
    id: root
    property var spec: []
    Component.onCompleted: Hypr.loadSchema(false)
    status: Hypr.schemaLoaded ? "" : "reading options…"
    readonly property var groups: {
        if (!Hypr.schemaLoaded) return []
        const out = []
        let g = null
        for (const item of spec) {
            if (typeof item === "object" && (item.group !== undefined || item.section !== undefined)) {
                g = { title: item.group ?? item.section, hint: item.hint ?? "", advanced: !!item.advanced, rows: [] }
                out.push(g)
                continue
            }
            const name = typeof item === "object" ? item.row : item
            if (!Hypr.schema[name]) continue
            if (!g) { g = { title: "", hint: "", advanced: false, rows: [] }; out.push(g) }
            g.rows.push(typeof item === "object" ? item : { row: name })
        }
        return out.filter(x => x.rows.length > 0)
    }
    Repeater {
        model: root.groups
        Group {
            required property var modelData
            title: modelData.title
            hint: modelData.hint
            advanced: modelData.advanced
            Repeater {
                model: modelData.rows
                OptionRow {
                    required property var modelData
                    name: modelData.row
                    label: modelData.label ?? pretty(modelData.row)
                    hint: modelData.hint ?? sentence(entry.description || "")
                }
            }
        }
    }
}
