import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Theme
import qs.Widgets
import qs.Services
// Album art, title, artist, a progress bar and the transport for whatever is playing.
RowLayout {
    id: root
    readonly property var w: parent.widget
    readonly property bool controls: Desktop.option(w, "controls") !== false
    readonly property var player: Media.player ?? (Mpris.players.values.find(p => p.trackTitle) ?? null)
    property real pos: 0
    Timer { interval: 1000; running: root.player !== null && root.player.isPlaying; repeat: true; triggeredOnStart: true
        onTriggered: { if (root.player && typeof root.player.positionChanged === "function") root.player.positionChanged(); root.pos = root.player ? root.player.position : 0 } }
    spacing: 16
    Rectangle {
        Layout.preferredWidth: Math.min(parent.height, 110); Layout.preferredHeight: Layout.preferredWidth
        radius: Tokens.rMd; color: Colors.surfaceContainerHigh; clip: true
        Image { anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 220; sourceSize.height: 220 }
        Glyph { anchors.centerIn: parent; text: "󰎈"; size: 32; visible: !root.player || !root.player.trackArtUrl }
    }
    ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        spacing: 2
        Label { text: root.player ? (root.player.trackTitle || "Unknown title") : "Nothing playing"; size: Tokens.fontSizeTitle; Layout.fillWidth: true }
        Label { text: root.player ? (root.player.trackArtist || "") : ""; size: Tokens.fontSizeSmall; dim: true; Layout.fillWidth: true }
        Label { text: root.player ? (root.player.trackAlbum || "") : ""; size: Tokens.fontSizeTiny; dim: true; regular: true; Layout.fillWidth: true; visible: text.length > 0 }
        Item { Layout.fillHeight: true }
        Rectangle {
            visible: root.player !== null && root.player.lengthSupported
            Layout.fillWidth: true; implicitHeight: 4; radius: 2; color: Colors.surfaceContainerHighest
            Rectangle { width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.pos / root.player.length) : 0; height: parent.height; radius: 2; color: Colors.primary }
        }
        RowLayout {
            visible: root.controls && root.player !== null
            spacing: 2
            IconButton { glyph: "󰒮"; small: true; onClicked: if (root.player.canGoPrevious) root.player.previous() }
            IconButton { glyph: root.player && root.player.isPlaying ? "󰏤" : "󰐊"; small: true; onClicked: if (root.player.canTogglePlaying) root.player.togglePlaying() }
            IconButton { glyph: "󰒭"; small: true; onClicked: if (root.player.canGoNext) root.player.next() }
            Item { Layout.fillWidth: true }
            Label { text: root.player ? root.player.identity : ""; size: Tokens.fontSizeTiny; dim: true }
        }
    }
}
