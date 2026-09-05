import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Spotify transport (previous · play/pause · next) and the track label.
// Hidden when Spotify is not running or has nothing loaded.
RowLayout {
    id: root
    property var bar: null
    spacing: 0
    visible: !Media.stopped

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
