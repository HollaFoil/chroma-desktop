import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Theme
import qs.Widgets
import qs.Services
// A sticky note: click to type, saved as you go (~/.local/state/quickshell/notes/<id>.txt).
ColumnLayout {
    id: root
    readonly property var w: parent.widget
    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/notes/" + w.id + ".txt"
    spacing: 6
    Component.onCompleted: Proc.run(["mkdir", "-p", path.substring(0, path.lastIndexOf("/"))], () => file.reload())
    FileView { id: file; path: root.path; printErrors: false; onLoaded: { if (edit.text !== text()) edit.text = text() } }
    Timer { id: saveTimer; interval: 800; onTriggered: file.setText(edit.text) }
    Label { text: String(Desktop.option(root.w, "title") || "Notes"); size: Tokens.fontSizeTitle; color: Colors.primary }
    Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true
        contentWidth: width; contentHeight: edit.implicitHeight
        clip: true
        TextEdit {
            id: edit
            width: parent.width
            wrapMode: TextEdit.Wrap
            font.family: Tokens.fontFamily; font.pixelSize: Tokens.fontSizeSmall
            color: Colors.surfaceFg
            selectionColor: Tokens.alpha(Colors.primary, Tokens.aSelection)
            cursorDelegate: Rectangle { width: 2; color: Colors.primary; visible: edit.cursorVisible }
            onTextChanged: saveTimer.restart()
            Label { visible: !edit.text.length && !edit.activeFocus; text: "click to write…"; dim: true; regular: true; size: Tokens.fontSizeSmall }
        }
    }
}
