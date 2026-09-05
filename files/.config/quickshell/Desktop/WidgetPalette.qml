import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Arrange mode's toolbar: every widget type as a live, scaled-down preview.
// Click one to add it to this screen (it lands in the middle, ready to drag).
Card {
    id: pal
    required property string screenName
    slanted: false
    alpha: 0.85
    padX: 14; padY: 12
    spacing: 8
    RowLayout {
        Layout.fillWidth: true
        Label { text: "Widgets"; size: Tokens.fontSizeTitle; Layout.fillWidth: true }
        Label { text: "click to add · drag to move · corner to resize · 󰒓 for options · × removes"; size: Tokens.fontSizeTiny; dim: true; regular: true }
        Pill { text: "󰄬  Done"; small: true; on: true; onClicked: Desktop.editMode = false }
    }
    RowLayout {
        spacing: 10
        Repeater {
            model: Desktop.types
            Rectangle {
                id: tile
                required property string modelData
                readonly property var cat: Desktop.catalogue[modelData]
                readonly property real s: 0.42
                implicitWidth: 300 * s + 12
                implicitHeight: 150 * s + 34
                radius: Tokens.rMd
                color: tma.containsMouse ? Tokens.alpha(Colors.primary, Tokens.aHover) : Tokens.alpha(Colors.surfaceContainerHigh, 0.6)
                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                ColumnLayout {
                    anchors { fill: parent; margins: 6 }
                    spacing: 4
                    Item {
                        Layout.preferredWidth: 300 * tile.s; Layout.preferredHeight: 150 * tile.s
                        clip: true
                        Rectangle { anchors.fill: parent; radius: Tokens.rXs; color: Tokens.alpha(Colors.surface, 0.6) }
                        Item {
                            width: 300; height: 150
                            scale: tile.s
                            transformOrigin: Item.TopLeft
                            Loader {
                                anchors { fill: parent; margins: 12 }
                                property var widget: ({ id: "preview-" + tile.modelData.toLowerCase(), type: tile.modelData, options: {} })
                                property string screenName: ""
                                source: "widgets/" + tile.modelData + "Widget.qml"
                            }
                        }
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }   // previews are not interactive
                    }
                    RowLayout {
                        spacing: 6
                        Glyph { text: tile.cat.glyph; size: 13 }
                        Label { text: tile.cat.name; size: Tokens.fontSizeTiny; Layout.fillWidth: true }
                    }
                }
                MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Desktop.add(pal.screenName, tile.modelData, true) }
            }
        }
    }
}
