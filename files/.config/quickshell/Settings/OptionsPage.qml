import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// A page that is a list of Hyprland options: `spec` items are option names or
// { section: "Title" }. Unknown names are skipped, so a page keeps working
// across Hyprland versions.
PageBody {
    id: root
    property var spec: []
    Component.onCompleted: Hypr.loadSchema(false)
    status: Hypr.schemaLoaded ? "" : "reading options…"
    readonly property var rows: {
        if (!Hypr.schemaLoaded) return []
        const out = []
        let first = true
        for (const item of spec) {
            if (typeof item === "object") { out.push({ section: item.section, first }); first = false; continue }
            if (!Hypr.schema[item]) continue
            out.push({ name: item }); first = false
        }
        return out
    }
    Repeater {
        model: root.rows
        delegate: Loader {
            required property var modelData
            Layout.fillWidth: true
            sourceComponent: modelData.section !== undefined ? sectionComp : rowComp
            Component { id: sectionComp; SectionTitle { text: modelData.section; first: modelData.first } }
            Component { id: rowComp; OptionRow { name: modelData.name } }
        }
    }
}
