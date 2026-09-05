import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// mute · slider · percent, for one Pipewire node, with room for a trailing control.
RowLayout {
    id: root
    property var node: null
    property bool mic: false
    property int sliderWidth: 190
    default property alias trailing: trail.data
    readonly property bool muted: node && node.audio ? node.audio.muted : false
    readonly property real vol: node && node.audio ? node.audio.volume : 0
    spacing: Tokens.sp2

    IconButton {
        glyph: root.mic ? Audio.micIcon(root.muted) : Audio.speakerIcon(Math.round(root.vol * 100), root.muted)
        kind: root.muted ? "muted" : "default"
        onClicked: Audio.toggleMute(root.node)
    }
    Slider {
        Layout.fillWidth: true
        minWidth: root.sliderWidth
        value: Math.min(1, root.vol)
        muted: root.muted
        step: 0.01
        onMoved: v => Audio.setVolume(root.node, v)
    }
    Label { text: Math.round(root.vol * 100) + "%"; size: Tokens.fontSizeSmall; dim: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 44 }
    RowLayout { id: trail; spacing: Tokens.sp1 }
}
