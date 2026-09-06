import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets

// A titled card of SettingRows: the unit every page is built from.
//     ┌ Title                            [trailing] ┐
//     │ hint                                        │
//     │ row ─────────────────────────────────────── │
//     │ row                                         │
//     └─────────────────────────────────────────────┘
// `advanced: true` collapses it under a chevron (the place for options most
// people never touch). While the window is being searched a group opens by
// itself and disappears when none of its rows match.
ColumnLayout {
    id: root
    property string title: ""
    property string hint: ""
    property bool advanced: false
    property bool collapsible: advanced
    property bool open: !advanced
    property string glyph: ""
    property alias trailing: trail.data
    default property alias content: body.data
    readonly property bool isSettingsGroup: true
    readonly property bool expanded: open || (SettingsSearch.active && hitCount > 0)
    property int rev: 0
    readonly property int hitCount: {
        SettingsSearch.q; rev
        let n = 0
        for (const c of body.children) if (c.isSettingRow === true && c.hit) n++
        return n
    }
    visible: !SettingsSearch.active || hitCount > 0 || SettingsSearch.matches(title + " " + hint)
    Layout.fillWidth: true
    spacing: 0

    function relayout() {
        let seen = 0
        for (const c of body.children) {
            if (c.isSettingRow !== true) continue
            if (!c.visible) continue
            c.lineAbove = seen > 0
            seen++
        }
    }
    function watch(c) { if (c.isSettingRow === true) c.visibleChanged.connect(root.relayout) }
    Component.onCompleted: { for (const c of body.children) watch(c); relayout() }
    Connections { target: body; function onChildrenChanged() { for (const c of body.children) root.watch(c); root.rev++; Qt.callLater(root.relayout) } }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 12
        radius: Tokens.rMd
        color: Tokens.alpha(Colors.surfaceContainerHigh, 0.5)
        Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 6; leftMargin: 6; rightMargin: 6 }
            spacing: 0
            ListRow {
                Layout.fillWidth: true
                visible: root.title.length > 0 || trail.children.length > 0
                accent: false
                clickable: root.collapsible
                padX: 8; padY: 4
                spacing: 8
                onClicked: root.open = !root.open
                Glyph { visible: root.glyph.length > 0; text: root.glyph; size: Tokens.fontSizeIconSmall; Layout.preferredWidth: 18 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: root.title; size: Tokens.fontSizeSmall; color: Colors.primary; Layout.fillWidth: true }
                    Label { visible: root.hint.length > 0; text: root.hint; size: Tokens.fontSizeTiny; dim: true; regular: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
                }
                RowLayout { id: trail; spacing: Tokens.sp2 }
                Glyph { visible: root.collapsible; text: root.expanded ? "󰅀" : "󰅂"; size: Tokens.fontSizeIconSmall; color: Colors.surfaceVariantFg }
            }
            Revealer {
                open: root.expanded
                Layout.fillWidth: true
                spacing: 0
                ColumnLayout { id: body; Layout.fillWidth: true; spacing: 0 }
            }
        }
    }
}
