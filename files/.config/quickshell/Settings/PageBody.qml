import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets

// What every settings page is made of: a title with a one-line subtitle and
// room for buttons on the right, a status line, then a scrolling column of
// Groups. `settingsPageIndex` is set by the window so rows can register their
// words with the search.
ColumnLayout {
    id: root
    property string title: ""
    property string subtitle: ""
    property int maxHeight: 750
    property int settingsPageIndex: -1
    property alias headerItems: trail.data
    property alias status: statusLine.text
    property alias statusError: statusLine.error
    default property alias content: body.content
    spacing: Tokens.sp2

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 8
        spacing: Tokens.sp3
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label { text: root.title; size: Tokens.fontSizeHeading; color: Colors.primary; Layout.fillWidth: true }
            Label { visible: root.subtitle.length > 0; text: root.subtitle; size: Tokens.fontSizeTiny; dim: true; regular: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
        RowLayout { id: trail; spacing: Tokens.sp2; Layout.alignment: Qt.AlignTop }
    }
    StatusLine { id: statusLine; Layout.fillWidth: true; leftPadding: 6 }
    Label {
        visible: SettingsSearch.active && root.visibleGroups === 0
        text: "nothing on this page matches “" + SettingsSearch.query.trim() + "”"
        size: Tokens.fontSizeSmall; dim: true; regular: true; leftPadding: 6
    }
    // rows hand their words up here; the window sets the index later, so the
    // registration happens whenever either side is ready
    property string words: ""
    function addWords(t) { words += " " + t }
    onWordsChanged: if (settingsPageIndex >= 0) SettingsSearch.setWords(settingsPageIndex, words)
    onSettingsPageIndexChanged: if (settingsPageIndex >= 0) SettingsSearch.setWords(settingsPageIndex, words)
    property int visibleGroups: -1
    function recount() {
        let n = 0
        for (const c of body.column.children) if (c.visible && c.isSettingsGroup === true) n++
        // pages without Groups (Audio, Wallpapers…) are never "empty"
        visibleGroups = body.column.children.some(c => c.isSettingsGroup === true) ? n : -1
    }
    Connections { target: SettingsSearch; function onQChanged() { Qt.callLater(root.recount) } }
    Connections { target: body.column; function onChildrenChanged() { Qt.callLater(root.recount) } }
    Component.onCompleted: Qt.callLater(recount)
    Scroller {
        id: body
        Layout.fillWidth: true
        maxHeight: root.maxHeight
        spacing: Tokens.sp2
    }
}
