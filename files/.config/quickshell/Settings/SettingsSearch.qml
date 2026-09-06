pragma Singleton
import QtQuick
import Quickshell

// The settings window's search: one query that the nav filters pages by and
// every SettingRow filters itself by. Rows register their words per page as
// they are built, so a page that has been opened once is searchable by its
// labels; pages never opened match on the keywords SettingsWindow lists.
Singleton {
    id: root
    property string query: ""
    readonly property string q: query.trim().toLowerCase()
    readonly property bool active: q.length > 0
    property var registry: ({})           // page index -> "label hint keywords ..." (lowercase)

    function matches(text) { return !active || String(text).toLowerCase().indexOf(q) >= 0 }
    function setWords(page, text) {
        if (page === undefined || page < 0) return
        const r = Object.assign({}, registry)
        r[page] = String(text).toLowerCase()
        registry = r
    }
    function pageMatches(page, staticText) {
        if (!active) return true
        return String(staticText).toLowerCase().indexOf(q) >= 0 || (registry[page] || "").indexOf(q) >= 0
    }
}
