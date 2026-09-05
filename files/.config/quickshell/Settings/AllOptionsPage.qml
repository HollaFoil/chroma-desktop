import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Every option Hyprland reports, one collapsible section per config group,
// with a filter that matches names and descriptions. Rows are built when a
// section first opens.
PageBody {
    id: root
    title: "All options"
    readonly property var hidden: ["debug", "opengl", "quirks", "experimental"]
    property string query: ""
    Component.onCompleted: Hypr.loadSchema(false)
    status: Hypr.schemaLoaded ? "" : "reading options…"
    headerItems: [ Entry { placeholder: "filter options…"; Layout.preferredWidth: 260; onTextChanged: root.query = text.trim().toLowerCase() } ]

    readonly property var groups: {
        const g = {}
        for (const name of Object.keys(Hypr.schema)) {
            const head = name.split(":")[0]
            if (hidden.indexOf(head) >= 0) continue
            (g[head] = g[head] || []).push(name)
        }
        return Object.keys(g).sort().map(k => ({ name: k, options: g[k] }))
    }
    function hits(names) {
        if (!query) return names
        return names.filter(n => n.toLowerCase().indexOf(query) >= 0 || ((Hypr.schema[n] || {}).description || "").toLowerCase().indexOf(query) >= 0)
    }

    Repeater {
        model: root.groups
        ColumnLayout {
            id: sec
            required property var modelData
            property bool opened: false
            readonly property var shown: root.hits(modelData.options)
            readonly property bool expanded: opened || root.query.length > 0
            visible: shown.length > 0
            Layout.fillWidth: true
            spacing: 4
            ListRow {
                Layout.fillWidth: true
                padX: 6; padY: 4
                onClicked: sec.opened = !sec.opened
                Glyph { text: sec.expanded ? "󰅀" : "󰅂"; size: Tokens.fontSizeSmall; color: Colors.surfaceVariantFg; Layout.preferredWidth: 16 }
                Label { text: sec.modelData.name; size: Tokens.fontSizeSmall; color: Colors.primary; Layout.fillWidth: true }
                Label { text: String(sec.shown.length); size: Tokens.fontSizeSmall; dim: true }
            }
            Revealer {
                open: sec.expanded
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: sec.expanded ? sec.shown : []
                    OptionRow { required property var modelData; name: modelData; Layout.fillWidth: true }
                }
            }
        }
    }
}
