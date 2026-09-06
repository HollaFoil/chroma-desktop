import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets

// One setting: a label with a small hint under it on the left, its control on
// the right (children land there). Shapes:
//     Label                                    [toggle | pills | slider | entry | picker]
//     hint in small dim text
//   value: "text"        read-only text on the right instead of a control
//   clickable: true      a row that opens something: chevron on the right
//   wide: true           the control sits under the label, full width
// Rows filter themselves by the window's search; a Group draws hairlines
// between the rows it shows and hides itself when none match.
Rectangle {
    id: root
    property string label: ""
    property string hint: ""
    property string keywords: ""
    property string value: ""
    property bool wide: false
    property bool clickable: false
    property bool lineAbove: false
    property alias afterLabel: afterLabelSlot.data
    default property alias controls: ctl.data
    readonly property bool isSettingRow: true
    readonly property bool hit: SettingsSearch.matches(label + " " + hint + " " + keywords)
    signal clicked()

    visible: hit
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 12
    radius: Tokens.rSm
    color: (hover.containsMouse && root.enabled) ? Tokens.alpha(root.clickable ? Colors.primary : Colors.surfaceFg, root.clickable ? Tokens.aHover : 0.04) : "transparent"
    Behavior on color { ColorAnimation { duration: Tokens.durFast } }
    opacity: enabled ? 1 : 0.5

    Component.onCompleted: {
        let p = parent
        while (p) { if (p.addWords !== undefined && p.settingsPageIndex !== undefined) { p.addWords(label + " " + hint + " " + keywords); break } p = p.parent }
    }

    Rectangle { visible: root.lineAbove; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 } height: 1; color: Tokens.alpha(Colors.outlineVariant, 0.35) }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.clickable ? Qt.LeftButton : Qt.NoButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 6; leftMargin: 8; rightMargin: 8 }
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            // capped so every row's control starts in the same column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: root.wide ? 660 : 430
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                RowLayout {
                    spacing: 6
                    Label { text: root.label; Layout.maximumWidth: 420 }
                    RowLayout { id: afterLabelSlot; spacing: 4 }
                }
                Label { visible: root.hint.length > 0; text: root.hint; size: Tokens.fontSizeTiny; dim: true; regular: true; wrapMode: Text.Wrap; Layout.fillWidth: true; Layout.maximumWidth: root.wide ? 660 : 420 }
            }
            RowLayout { id: inlineHost; spacing: 8; visible: !root.wide; Layout.alignment: Qt.AlignVCenter }
            Label { visible: root.value.length > 0; text: root.value; size: Tokens.fontSizeSmall; dim: true; regular: true; horizontalAlignment: Text.AlignRight; Layout.maximumWidth: 380; Layout.alignment: Qt.AlignVCenter }
            Glyph { visible: root.clickable; text: "󰅂"; size: Tokens.fontSizeIconSmall; color: Colors.surfaceVariantFg }
        }
        RowLayout { id: wideHost; spacing: 8; visible: root.wide; Layout.fillWidth: true }
        RowLayout { id: ctl; spacing: 8; parent: root.wide ? wideHost : inlineHost; Layout.fillWidth: root.wide }
    }
}
