import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Theme
import qs.Widgets
import qs.Services

// Notification bell. Until the shell is the notification daemon (Phase 2)
// this follows `swaync-client -swb` and drives swaync.
Bubble {
    id: root
    corners: "mirror"
    padL: 16; padR: 16
    marginL: 5; marginR: 5
    property int count: 0
    property bool dnd: false

    Process {
        id: sub
        command: ["swaync-client", "-swb"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const j = JSON.parse(data)
                    root.count = parseInt(j.text) || 0
                    root.dnd = String(j.alt || "").indexOf("dnd") >= 0
                } catch (e) {}
            }
        }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: sub.running = true }

    onClicked: Proc.detach(["swaync-client", "-t", "-sw"])
    onRightClicked: Proc.detach(["swaync-client", "-d", "-sw"])

    Label { text: root.count > 0 ? String(root.count) : ""; size: Tokens.fontSizeBar; visible: root.count > 0 }
    Item {
        implicitWidth: bell.implicitWidth + 4
        implicitHeight: bell.implicitHeight
        Glyph { id: bell; anchors.centerIn: parent; text: root.dnd ? "󰂛" : "󰂚"; size: Tokens.fontSizeBar + 2; color: Colors.surfaceFg }
        Rectangle { visible: root.count > 0; width: 6; height: 6; radius: 3; color: Colors.error; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 6 }
    }
}
