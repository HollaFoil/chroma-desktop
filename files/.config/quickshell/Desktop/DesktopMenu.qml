import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// The desktop's right-click menu.
Card {
    id: menu
    required property string screenName
    signal closed()
    slanted: false
    alpha: 0.85
    padX: 6; padY: 6
    spacing: 1
    minWidth: 220
    readonly property var items: [
        { glyph: "󰐕", text: "Add a widget…",        run: () => { Desktop.editMode = true } },
        { glyph: "󰆾", text: Desktop.editMode ? "Done arranging" : "Arrange widgets", run: () => { Desktop.editMode = !Desktop.editMode } },
        { glyph: "󰸉", text: "Change wallpaper…",    run: () => Overlays.toggleWallStrip() },
        { glyph: "󰒓", text: "Widget settings",      run: () => Overlays.openSettings("Widgets") }
    ]
    Repeater {
        model: menu.items
        ListRow {
            required property var modelData
            Layout.fillWidth: true
            padX: 10; padY: 6
            spacing: 12
            onClicked: { menu.closed(); modelData.run() }
            Glyph { text: modelData.glyph; size: 16; Layout.preferredWidth: 20 }
            Label { text: modelData.text; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
        }
    }
}
