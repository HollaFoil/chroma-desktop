import QtQuick
import qs.Theme

// A row of pills with one `on`: the stand-in for a combo box, so a choice
// never needs a popup of its own.
Row {
    id: root
    property var model: []
    property int current: -1
    property bool small: true
    signal picked(int index)
    spacing: Tokens.sp1

    Repeater {
        model: root.model
        Pill {
            required property int index
            required property var modelData
            text: String(modelData)
            on: index === root.current
            small: root.small
            minWidth: 0
            enabled: root.enabled
            onClicked: root.picked(index)
        }
    }
}
