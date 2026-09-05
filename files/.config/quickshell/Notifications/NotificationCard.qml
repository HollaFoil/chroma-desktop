import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// One notification: icon, summary, time, body, actions, an inline reply.
// The same card is the toast and the row in the centre (`inCenter`).
Rectangle {
    id: root
    required property var entry
    property bool inCenter: false
    signal closed()
    readonly property string iconSource: {
        const e = entry
        if (e.image) return e.image.startsWith("/") ? "file://" + e.image : e.image
        if (e.icon) {
            if (e.icon.startsWith("/")) return "file://" + e.icon
            if (e.icon.indexOf(":") > 0) return e.icon
            return Quickshell.iconPath(e.icon, true)
        }
        return ""
    }

    implicitHeight: col.implicitHeight + 24
    radius: inCenter ? Tokens.rLg : Tokens.rCardA
    color: inCenter ? Colors.surfaceContainerHighest : Tokens.alpha(Colors.surface, Tokens.aCard)
    border.width: entry.urgency === 2 ? 1 : 0
    border.color: Tokens.alpha(Colors.error, 0.6)
    Behavior on color { ColorAnimation { duration: Tokens.durSlow } }

    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.activate(root.entry) }

    RowLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12
        Item {
            Layout.preferredWidth: 48; Layout.preferredHeight: 48
            Layout.alignment: Qt.AlignTop
            visible: root.iconSource !== "" || root.entry.urgency === 2
            Rectangle { anchors.fill: parent; radius: Tokens.rMd; color: Colors.surfaceContainerHigh; clip: true
                Image { anchors.fill: parent; source: root.iconSource; sourceSize.width: 48; sourceSize.height: 48; fillMode: Image.PreserveAspectCrop; asynchronous: true } }
            Glyph { anchors.centerIn: parent; text: "󰀦"; size: 22; color: Colors.error; visible: root.iconSource === "" }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: root.entry.summary || root.entry.app; Layout.fillWidth: true; maximumLineCount: 2; wrapMode: Text.Wrap }
                Label { text: Notifs.tick, Notifs.ago(root.entry.time); size: Tokens.fontSizeTiny; dim: true }
                IconButton { glyph: "󰅖"; kind: "action"; small: true; onClicked: { Notifs.dismiss(root.entry.key); root.closed() } }
            }
            Label { text: root.entry.app; size: Tokens.fontSizeTiny; dim: true; visible: root.entry.summary.length > 0 && root.entry.app !== root.entry.summary }
            Label {
                visible: root.entry.body.length > 0
                text: root.entry.body
                size: Tokens.fontSizeSmall
                regular: true
                wrapMode: Text.Wrap
                maximumLineCount: 8
                textFormat: Text.StyledText
                linkColor: Colors.primary
                Layout.fillWidth: true
                onLinkActivated: link => Proc.detach(["xdg-open", link])
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: root.entry.actions.filter(a => a.id !== "default").length > 0
                Repeater {
                    model: root.entry.actions.filter(a => a.id !== "default")
                    Pill { required property var modelData; text: modelData.text || modelData.id; small: true; minWidth: 0; onClicked: Notifs.invoke(root.entry, modelData.id) }
                }
            }
            RowLayout {
                visible: root.entry.hasReply
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                Entry { id: replyField; Layout.fillWidth: true; placeholder: root.entry.replyPlaceholder; onAccepted: { Notifs.reply(root.entry, text); text = "" } }
                IconButton { glyph: "󰒊"; small: true; onClicked: { Notifs.reply(root.entry, replyField.text); replyField.text = "" } }
            }
        }
    }
}
