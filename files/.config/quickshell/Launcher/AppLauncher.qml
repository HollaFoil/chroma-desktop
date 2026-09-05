import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// The app launcher: type, arrow, Enter. Most-used apps come first when the
// search is empty.
OverlayWindow {
    id: win
    placement: "center"
    property bool isOpen: false
    property var allowedScreens: Quickshell.screens
    property int sel: 0
    readonly property int limit: 8
    readonly property var results: Apps.search(search.text, limit)
    open: isOpen
    onDismissed: isOpen = false
    function show() {
        const focused = Hyprland.focusedMonitor
        const s = allowedScreens.find(sc => focused && sc.name === focused.name) ?? allowedScreens[0]
        if (s) screen = s
        search.text = ""; sel = 0
        isOpen = true
        Qt.callLater(() => search.input.forceActiveFocus())
    }
    function toggle() { if (isOpen) isOpen = false; else show() }
    function launch(e) { if (!e) return; isOpen = false; Apps.launch(e) }
    onResultsChanged: sel = 0

    Card {
        slanted: false
        padX: 16; padY: 14
        minWidth: 720
        spacing: 10
        SearchField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            placeholder: "Search applications"
            onAccepted: win.launch(win.results[win.sel])
            onDown: win.sel = Math.min(win.results.length - 1, win.sel + 1)
            onUp: win.sel = Math.max(0, win.sel - 1)
        }
        Divider { Layout.fillWidth: true; gap: 2 }
        Repeater {
            model: win.results
            ListRow {
                id: row
                required property var modelData
                required property int index
                Layout.fillWidth: true
                padX: 10; padY: 6
                spacing: 14
                active: index === win.sel
                onClicked: win.launch(modelData)
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: Tokens.rXs; color: "transparent"
                    Image { anchors.fill: parent; source: Apps.icon(row.modelData); sourceSize.width: 32; sourceSize.height: 32; fillMode: Image.PreserveAspectFit; asynchronous: true }
                    Glyph { anchors.centerIn: parent; text: "󰣆"; size: 20; visible: !row.modelData.icon; color: Colors.surfaceVariantFg }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: row.modelData.name; color: row.active ? Colors.primary : Colors.surfaceFg; Layout.fillWidth: true }
                    Label { text: row.modelData.genericName || row.modelData.comment || ""; size: Tokens.fontSizeTiny; dim: true; regular: true; Layout.fillWidth: true; visible: text.length > 0 }
                }
                Label { text: Apps.counts[row.modelData.id] ? "󰄲 " + Apps.counts[row.modelData.id] : ""; size: Tokens.fontSizeTiny; dim: true; visible: text.length > 0 }
            }
        }
        Label { visible: win.results.length === 0; text: "nothing matches"; dim: true; regular: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; topPadding: 10; bottomPadding: 10 }
    }
}
