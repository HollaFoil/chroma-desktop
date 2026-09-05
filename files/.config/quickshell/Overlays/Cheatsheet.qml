import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// The keybind cheatsheet: a frosted card in the middle of the screen with the
// current binds in two columns, sections kept whole and dealt to the side
// that makes the columns closest in height (the split comes with the export
// from lib/actions.lua). Any key or a click closes it.
OverlayWindow {
    id: win
    placement: "center"
    anyKeyCloses: true
    property bool isOpen: false
    property var allowedScreens: Quickshell.screens
    open: isOpen
    onDismissed: isOpen = false
    function show() {
        const focused = Hyprland.focusedMonitor
        const s = allowedScreens.find(sc => focused && sc.name === focused.name) ?? allowedScreens[0]
        if (s) screen = s
        isOpen = true
    }
    function toggle() { if (isOpen) isOpen = false; else show() }

    function keyText(a) {
        if (a.keys_label) return a.keys_label
        const keys = a.keys || []
        if (a.parametrised) { const suffix = a.params_label || ""; return keys.map(k => k ? k + " + " + suffix : suffix).join(" / ") }
        return keys.join(" / ")
    }
    // [[{title, rows: [[key, name]]}], [...]]
    readonly property var columns: {
        const rows = {}
        for (const a of Binds.actions) {
            if (a.cheatsheet === false || !(a.keys || []).length) continue
            ;(rows[a.category] = rows[a.category] || []).push([keyText(a), a.name])
        }
        const cols = Binds.columns
        if (cols && cols.length === 2 && cols.every(col => col.every(c => rows[c])))
            return cols.map(col => col.map(c => ({ title: c, rows: rows[c] })))
        const order = Binds.categories.filter(c => rows[c]).concat(Object.keys(rows).filter(c => Binds.categories.indexOf(c) < 0))
        const blocks = order.map(c => ({ title: c, rows: rows[c] }))
        const heights = blocks.map(b => b.rows.length + 2), total = heights.reduce((a, b) => a + b, 0)
        let best = 1, bestDiff = -1, running = 0
        for (let i = 1; i < heights.length; i++) { running += heights[i - 1]; const d = Math.abs(running - (total - running)); if (bestDiff < 0 || d < bestDiff) { best = i; bestDiff = d } }
        return [blocks.slice(0, best), blocks.slice(best)]
    }

    Card {
        slanted: false
        padX: 34; padY: 28
        RowLayout {
            spacing: 56
            Repeater {
                model: win.columns
                GridLayout {
                    id: col
                    required property var modelData
                    columns: 2
                    rowSpacing: 4; columnSpacing: 22
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: {
                            const cells = []
                            col.modelData.forEach((block, bi) => {
                                cells.push({ title: block.title, first: bi === 0 })
                                for (const r of block.rows) { cells.push({ key: r[0] }); cells.push({ desc: r[1] }) }
                            })
                            return cells
                        }
                        Label {
                            required property var modelData
                            text: modelData.title ?? modelData.key ?? modelData.desc ?? ""
                            color: modelData.title !== undefined ? Colors.primary : modelData.key !== undefined ? Colors.surfaceFg : Colors.surfaceVariantFg
                            regular: modelData.desc !== undefined
                            Layout.columnSpan: modelData.title !== undefined ? 2 : 1
                            Layout.topMargin: modelData.title !== undefined && !modelData.first ? 14 : 0
                            Layout.bottomMargin: modelData.title !== undefined ? 4 : 0
                        }
                    }
                }
            }
        }
    }
}
