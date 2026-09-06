import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// A grid of wallpaper previews; click one to run setwall.
PageBody {
    id: root
    title: "Wallpapers"
    subtitle: "Pick one; the palette of everything follows it"
    readonly property var stripKeys: Binds.keysOf("util.wallpaper")
    headerItems: [ Pill { text: "Open strip" + (root.stripKeys.length ? "  (" + Binds.prettyCombo(root.stripKeys[0]) + ")" : ""); small: true
                          onClicked: { Overlays.settingsToggle(); Overlays.toggleWallStrip() } } ]
    Component.onCompleted: Wallpapers.refresh()
    status: Wallpapers.files.length === 0 ? "no images in " + Wallpapers.dir : ""

    GridLayout {
        columns: 4
        rowSpacing: 8; columnSpacing: 8
        Layout.leftMargin: 2
        Repeater {
            model: Wallpapers.files
            Rectangle {
                id: tile
                required property string modelData
                readonly property bool current: Wallpapers.current === modelData
                Layout.preferredWidth: 208; Layout.preferredHeight: 138
                radius: Tokens.rMd
                color: current ? Tokens.alpha(Colors.primary, Tokens.aActive) : tma.containsMouse ? Tokens.alpha(Colors.primary, Tokens.aHover) : "transparent"
                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2
                    Item {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 112
                        Image {
                            id: img
                            anchors.fill: parent
                            source: "file://" + tile.modelData
                            sourceSize.width: 400; sourceSize.height: 225
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }
                        Rectangle { id: mask; anchors.fill: parent; radius: Tokens.rXs; visible: false }
                        // rounded corners without a shader effect: clip the image inside a rounded rectangle
                        Rectangle { anchors.fill: parent; radius: Tokens.rXs; color: Colors.surfaceContainerHigh; clip: true
                            Image { anchors.fill: parent; source: img.source; sourceSize: img.sourceSize; fillMode: Image.PreserveAspectCrop; asynchronous: true } }
                    }
                    Label { text: Wallpapers.stem(tile.modelData); size: Tokens.fontSizeMicro; regular: true; horizontalAlignment: Text.AlignHCenter; color: tile.current ? Colors.primary : Colors.surfaceVariantFg; Layout.fillWidth: true }
                }
                MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Wallpapers.apply(tile.modelData); root.status = "applying " + Wallpapers.stem(tile.modelData) + "…" } }
            }
        }
    }
}
