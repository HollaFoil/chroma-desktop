import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Notification bell: the count, a dot when there is anything, the slashed
// bell under do-not-disturb. Click opens the centre, right click toggles DND.
Bubble {
    id: root
    corners: "mirror"
    padL: 16; padR: 16
    marginL: 5; marginR: 5
    onClicked: Overlays.toggleNotifs()
    onRightClicked: Notifs.dnd = !Notifs.dnd

    Label { text: Notifs.count > 0 ? String(Notifs.count) : ""; size: Tokens.fontSizeBar; visible: Notifs.count > 0 }
    Item {
        implicitWidth: bell.implicitWidth + 4
        implicitHeight: bell.implicitHeight
        Glyph { id: bell; anchors.centerIn: parent; text: Notifs.dnd ? "󰂛" : "󰂚"; size: Tokens.fontSizeBar + 2; color: Colors.surfaceFg }
        Rectangle { visible: Notifs.count > 0; width: 6; height: 6; radius: 3; color: Colors.error; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 6 }
    }
}
