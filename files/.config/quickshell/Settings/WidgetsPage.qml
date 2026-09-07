import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Desktop widgets: what sits on which screen, their options, and edit mode
// for arranging them on the desktop itself.
PageBody {
    id: root
    title: "Widgets"
    subtitle: "What sits on the desktop, per screen"
    headerItems: [ Pill { text: Desktop.editMode ? "󰄬  Done arranging" : "󰆾  Arrange on the desktop"; small: true; on: Desktop.editMode; onClicked: { Desktop.editMode = !Desktop.editMode; if (Desktop.editMode) Overlays.settingsToggle() } } ]
    property string addTo: Quickshell.screens.length ? Quickshell.screens[0].name : ""

    Label { text: "Widgets sit over the wallpaper and under your windows. The desktop itself is where they are set up: right-click the wallpaper, or Arrange, for the palette, moving, resizing and each widget's options. Positions are saved in ~/.local/state/quickshell/layout.json (Desktop/layout.json in the config is only the starting point); a hand-edited file is picked up live."; size: Tokens.fontSizeTiny; dim: true; regular: true; wrapMode: Text.Wrap; Layout.fillWidth: true; leftPadding: 6 }
    Repeater {
        model: Quickshell.screens
        Group {
            id: scr
            required property var modelData
            readonly property var widgets: Desktop.revision, Desktop.widgetsOn(modelData.name)
            title: scr.modelData.name
            hint: scr.modelData.width + " × " + scr.modelData.height + "  ·  " + scr.widgets.length + (scr.widgets.length === 1 ? " widget" : " widgets")
            Label { visible: scr.widgets.length === 0; text: "no widgets on this screen"; size: Tokens.fontSizeSmall; dim: true; regular: true; leftPadding: 6 }
            Repeater {
                model: scr.widgets
                ColumnLayout {
                    id: row
                    required property var modelData
                    readonly property var cat: Desktop.catalogue[modelData.type] || { name: modelData.type, glyph: "󰘔", options: [] }
                    property bool open: false
                    Layout.fillWidth: true
                    spacing: 2
                    ListRow {
                        Layout.fillWidth: true
                        accent: false
                        padX: 6; padY: 4
                        onClicked: row.open = !row.open
                        Glyph { text: row.cat.glyph; size: 17; Layout.preferredWidth: 24 }
                        Label { text: row.cat.name; Layout.fillWidth: true }
                        Label { text: row.modelData.w + "×" + row.modelData.h + " at " + row.modelData.x + ", " + row.modelData.y; size: Tokens.fontSizeTiny; dim: true }
                        IconButton { glyph: row.open ? "󰅃" : "󰅀"; kind: "action"; small: true; visible: row.cat.options.length > 0; onClicked: row.open = !row.open }
                        IconButton { glyph: "󰆴"; kind: "danger"; small: true; onClicked: Desktop.remove(scr.modelData.name, row.modelData.id) }
                    }
                    Revealer {
                        open: row.open && row.cat.options.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 36
                        Repeater {
                            model: row.cat.options
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Label { text: modelData.label; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
                                Toggle { visible: modelData.type === "bool"; checked: Desktop.option(row.modelData, modelData.key) === true; onToggled: v => Desktop.setOption(scr.modelData.name, row.modelData.id, modelData.key, v) }
                                Entry { visible: modelData.type === "text"; Layout.preferredWidth: 260; text: String(Desktop.option(row.modelData, modelData.key) ?? ""); onEditingFinished: if (text !== String(Desktop.option(row.modelData, modelData.key) ?? "")) Desktop.setOption(scr.modelData.name, row.modelData.id, modelData.key, text) }
                            }
                        }
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.topMargin: 4
                spacing: 6
                Label { text: "add:"; size: Tokens.fontSizeSmall; dim: true; height: 22; verticalAlignment: Text.AlignVCenter }
                Repeater {
                    model: Desktop.types
                    Pill { required property string modelData; text: Desktop.catalogue[modelData].glyph + "  " + Desktop.catalogue[modelData].name; small: true; minWidth: 0; onClicked: Desktop.add(scr.modelData.name, modelData) }
                }
            }
        }
    }
}
