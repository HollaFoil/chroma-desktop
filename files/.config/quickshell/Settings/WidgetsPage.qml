import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services
import qs.Desktop

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
            // the rows are keyed by id, so changing an option keeps its row (and fold) as it is
            readonly property string idKey: widgets.map(w => w.id).join("\n")
            title: scr.modelData.name
            hint: scr.modelData.width + " × " + scr.modelData.height + "  ·  " + scr.widgets.length + (scr.widgets.length === 1 ? " widget" : " widgets")
            Label { visible: scr.widgets.length === 0; text: "no widgets on this screen"; size: Tokens.fontSizeSmall; dim: true; regular: true; leftPadding: 6 }
            Repeater {
                model: scr.idKey ? scr.idKey.split("\n") : []
                ColumnLayout {
                    id: row
                    required property string modelData
                    readonly property var w: scr.widgets.find(o => o.id === modelData) || ({ id: modelData, type: "", x: 0, y: 0, w: 0, h: 0, options: {} })
                    readonly property var cat: Desktop.catalogue[w.type] || { name: w.type, glyph: "󰘔", options: [] }
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
                        Label { text: row.w.w + "×" + row.w.h + " at " + row.w.x + ", " + row.w.y; size: Tokens.fontSizeTiny; dim: true }
                        IconButton { glyph: row.open ? "󰅃" : "󰅀"; kind: "action"; small: true; visible: row.cat.options.length > 0; onClicked: row.open = !row.open }
                        IconButton { glyph: "󰆴"; kind: "danger"; small: true; onClicked: Desktop.remove(scr.modelData.name, row.w.id) }
                    }
                    Revealer {
                        open: row.open && row.cat.options.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 36
                        Repeater {
                            model: row.cat.options
                            OptionEditor {
                                required property var modelData
                                option: modelData
                                widget: row.w
                                screenName: scr.modelData.name
                                fieldWidth: 260
                                Layout.fillWidth: true
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
