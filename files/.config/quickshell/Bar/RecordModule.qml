import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Screen recording: a quiet dot that turns red and counts while recording.
// Click for the panel, right click stops.
Bubble {
    id: root
    corners: "mirror"
    padL: 12; padR: 12
    marginL: 5; marginR: 2
    onClicked: openPopup("record", "left")
    onRightClicked: Recorder.stop()
    Glyph {
        text: "󰑊"
        size: Tokens.fontSizeBar + 1
        color: Recorder.recording ? Colors.error : root.hovered ? Colors.primary : Colors.surfaceVariantFg
        SequentialAnimation on opacity {
            running: Recorder.recording
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        }
        onOpacityChanged: if (!Recorder.recording && opacity !== 1) opacity = 1
    }
    Label { visible: Recorder.recording; text: Recorder.clock(); size: Tokens.fontSizeBar; color: Colors.error; Layout.leftMargin: 6 }
}
