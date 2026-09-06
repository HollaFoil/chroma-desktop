import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Spotify transport (previous · play/pause · next), its own volume as a thin
// bar that widens under the pointer, and the track label. Hidden when Spotify
// is not running or has nothing loaded, or when the bar.media pref is off.
RowLayout {
    id: root
    property var bar: null
    spacing: 0
    visible: !Media.stopped && Prefs.get("bar.media", true)

    Bubble {
        id: back
        bar: root.bar; corners: "capLeft"; padL: 16; padR: 5; marginL: 7
        onClicked: Media.previous()
        onScrolled: d => Media.volumeStep(d > 0 ? 0.05 : -0.05)
        Glyph { text: "󰙣"; size: 20; color: back.hovered ? Colors.surfaceFg : Colors.tertiary }
    }
    Bubble {
        id: play
        bar: root.bar; corners: "none"; padL: 5; padR: 5; marginL: 0
        onClicked: Media.playPause()
        onScrolled: d => Media.volumeStep(d > 0 ? 0.05 : -0.05)
        Glyph { text: Media.playing ? "󰏤" : "󰐊"; size: 20; Layout.preferredWidth: 24; color: play.hovered ? Colors.surfaceFg : Colors.primary }
    }
    Bubble {
        id: fwd
        bar: root.bar; corners: "capRight"; padL: 5; padR: 12; marginL: 0; marginR: 7
        onClicked: Media.next()
        onScrolled: d => Media.volumeStep(d > 0 ? 0.05 : -0.05)
        Glyph { text: "󰙡"; size: 20; color: fwd.hovered ? Colors.surfaceFg : Colors.tertiary }
    }
    // Spotify's volume: its own pill, a bar that grows into a slider under the pointer
    Bubble {
        id: vol
        visible: Media.volumeSupported
        bar: root.bar; corners: "slant"; padL: 16; padR: 16; marginL: 0; marginR: 7
        interactive: false
        spacing: 10
        readonly property bool expanded: hover.hovered || track.pressed
        HoverHandler { id: hover }
        Glyph {
            text: Media.volume === 0 ? "󰝟" : Media.volume < 0.5 ? "󰖀" : "󰕾"
            size: 16
            color: vol.expanded ? Colors.primary : Colors.tertiary
        }
        Item {
            id: slider
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: vol.expanded ? 130 : 70
            implicitHeight: 16
            Behavior on implicitWidth { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easing } }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Colors.surfaceContainerHighest }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Media.volume; height: 6; radius: 3; color: vol.expanded ? Colors.primary : Colors.tertiary
                Behavior on color { ColorAnimation { duration: Tokens.durFast } } }
            Rectangle {
                width: 12; height: 12; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, parent.width * Media.volume - width / 2))
                color: Colors.primary
                opacity: vol.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            }
            MouseArea {
                id: track
                anchors.fill: parent
                anchors.topMargin: -6; anchors.bottomMargin: -6
                cursorShape: Qt.PointingHandCursor
                function at(x) { Media.setVolume(x / width) }
                onPressed: mouse => at(mouse.x)
                onPositionChanged: mouse => { if (pressed) at(mouse.x) }
                onWheel: wheel => Media.volumeStep(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }
    }
    Bubble {
        id: label
        bar: root.bar; corners: "slant"; marginL: 0
        onClicked: Media.playPause()
        Label {
            text: "󰎈 " + Media.label + " 󰎈"
            size: Tokens.fontSizeBar
            color: Media.playing ? Colors.surfaceFg : Colors.surfaceVariantFg
            Layout.maximumWidth: 360
        }
    }
}
