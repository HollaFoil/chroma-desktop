import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// Clipboard history (cliphist): filter, Enter copies, Ctrl+Del deletes the
// entry, Alt+Del wipes the history.
OverlayWindow {
    id: win
    placement: "center"
    property bool isOpen: false
    property var allowedScreens: Quickshell.screens
    property int sel: 0
    property string status: ""
    readonly property var results: {
        const q = search.text.trim().toLowerCase()
        return q ? Clipboard.entries.filter(e => e.summary.toLowerCase().indexOf(q) >= 0) : Clipboard.entries
    }
    open: isOpen
    onDismissed: isOpen = false
    function show() {
        const focused = Hyprland.focusedMonitor
        const s = allowedScreens.find(sc => focused && sc.name === focused.name) ?? allowedScreens[0]
        if (s) screen = s
        Clipboard.refresh()
        search.text = ""; sel = 0; status = ""
        isOpen = true
        Qt.callLater(() => search.input.forceActiveFocus())
    }
    function toggle() { if (isOpen) isOpen = false; else show() }
    function pick(e) { if (!e) return; isOpen = false; Clipboard.copy(e) }
    onResultsChanged: sel = Math.min(sel, Math.max(0, results.length - 1))

    Card {
        slanted: false
        padX: 16; padY: 14
        minWidth: 680
        spacing: 10
        SearchField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            glyph: "󰅌"
            placeholder: "Search clipboard"
            onAccepted: win.pick(win.results[win.sel])
            onDown: win.sel = Math.min(win.results.length - 1, win.sel + 1)
            onUp: win.sel = Math.max(0, win.sel - 1)
            onDeleteRequested: mods => {
                if (mods & Qt.AltModifier) { Clipboard.wipe(() => win.status = "history wiped"); }
                else if (win.results[win.sel]) { Clipboard.remove(win.results[win.sel], () => win.status = "entry deleted") }
            }
        }
        Divider { Layout.fillWidth: true; gap: 2 }
        Scroller {
            Layout.fillWidth: true
            maxHeight: 9 * 38
            spacing: 2
            Repeater {
                model: win.results
                ListRow {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    padX: 10; padY: 6
                    spacing: 12
                    active: index === win.sel
                    onClicked: win.pick(modelData)
                    Label { text: row.modelData.id; size: Tokens.fontSizeTiny; dim: true; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
                    Label { text: row.modelData.summary; size: Tokens.fontSizeSmall; regular: !row.modelData.image; color: row.active ? Colors.primary : Colors.surfaceFg; Layout.fillWidth: true; maximumLineCount: 1 }
                }
            }
            Label { visible: win.results.length === 0; text: Clipboard.entries.length ? "nothing matches" : "clipboard history is empty"; dim: true; regular: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; topPadding: 10; bottomPadding: 10 }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: win.status; size: Tokens.fontSizeTiny; color: Colors.primary; Layout.fillWidth: true; leftPadding: 6 }
            Label { text: "Enter copy · Ctrl+Del delete · Alt+Del wipe"; size: Tokens.fontSizeTiny; dim: true; regular: true }
        }
    }
}
