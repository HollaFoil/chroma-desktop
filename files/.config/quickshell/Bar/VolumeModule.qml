import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Default output: icon and percent. Click for the audio panel, right click
// mutes, scrolling steps 5 %.
Bubble {
    id: root
    corners: "mirror"
    readonly property var sink: Audio.defaultSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int pct: Audio.pct(sink)
    onClicked: openPopup("audio", "right")
    onRightClicked: Audio.toggleMute(sink)
    onScrolled: d => Audio.setVolume(sink, Math.min(1, (sink && sink.audio ? sink.audio.volume : 0) + (d > 0 ? 0.05 : -0.05)))
    Label {
        text: root.muted ? "󰝟" : Audio.speakerIcon(root.pct, false) + " " + root.pct + "%"
        size: Tokens.fontSizeBar
        color: root.muted ? Colors.surfaceVariantFg : Colors.surfaceFg
    }
}
