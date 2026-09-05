import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Screen recording: a ring-and-disk that turns red and counts while recording.
// Click for the panel, right click stops.
Bubble {
    id: root
    corners: "slant"
    padL: 12; padR: 12
    marginL: 5; marginR: 2
    onClicked: openPopup("record", "left")
    onRightClicked: Recorder.stop()
    // a ring with a disk inside: the record symbol
    Item {
        implicitWidth: 16; implicitHeight: 16
        Layout.alignment: Qt.AlignVCenter
        readonly property color c: Recorder.recording ? Colors.error : root.hovered ? Colors.primary : Colors.surfaceVariantFg
        Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.width: 2; border.color: parent.c
            Behavior on border.color { ColorAnimation { duration: Tokens.durFast } } }
        Rectangle {
            anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: parent.c
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            SequentialAnimation on opacity {
                running: Recorder.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
            onOpacityChanged: if (!Recorder.recording && opacity !== 1) opacity = 1
        }
    }
    Label { visible: Recorder.recording; text: Recorder.clock(); size: Tokens.fontSizeBar; color: Colors.error; Layout.leftMargin: 6 }
}
