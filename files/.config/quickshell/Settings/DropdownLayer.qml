import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets

// Fills the settings card and draws Dropdown's list under its anchor (above
// it when there is no room). A click anywhere else closes it. Long lists get
// a filter field that has the keyboard while the list is open.
Item {
    id: root
    visible: Dropdown.open
    z: 100

    readonly property var pos: {
        if (!Dropdown.anchor) return Qt.point(0, 0)
        return Dropdown.anchor.mapToItem(root, 0, Dropdown.anchor.height)
    }
    readonly property int listW: Math.min(380, Math.max(240, Dropdown.anchor ? Dropdown.anchor.width : 240))
    readonly property bool flipUp: pos.y + card.implicitHeight + 4 > root.height && pos.y > card.implicitHeight
    property string filter: ""
    readonly property var shown: {
        const f = filter.trim().toLowerCase()
        if (!f) return Dropdown.items
        return Dropdown.items.filter(it => (it.text + " " + (it.hint || "")).toLowerCase().indexOf(f) >= 0)
    }
    onVisibleChanged: {
        if (visible) { filter = ""; if (Dropdown.searchable) Qt.callLater(() => search.input.forceActiveFocus()); else root.forceActiveFocus() }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { Dropdown.close(); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (shown.length) Dropdown.pick(shown[0].value); event.accepted = true }
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: Dropdown.close() }
    Rectangle {
        id: card
        x: Math.max(4, Math.min(root.width - width - 4, Math.round(root.pos.x + (Dropdown.anchor ? Dropdown.anchor.width : 0) - width)))
        y: root.flipUp ? Math.round(root.pos.y - (Dropdown.anchor ? Dropdown.anchor.height : 0) - implicitHeight - 4) : Math.round(root.pos.y + 4)
        width: root.listW
        implicitHeight: col.implicitHeight + 12
        height: implicitHeight
        radius: Tokens.rMd
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: Tokens.alpha(Colors.outlineVariant, 0.5)
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // keeps the backdrop from seeing clicks in the list
        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 4
            Entry {
                id: search
                visible: Dropdown.searchable
                Layout.fillWidth: true
                placeholder: "Filter…"
                onTextChanged: root.filter = text
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { Dropdown.close(); event.accepted = true }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (root.shown.length) Dropdown.pick(root.shown[0].value); event.accepted = true }
                }
            }
            Scroller {
                Layout.fillWidth: true
                maxHeight: 264
                spacing: 1
                Repeater {
                    model: root.shown.slice(0, 400)
                    ListRow {
                        required property var modelData
                        Layout.fillWidth: true
                        padX: 8; padY: 4
                        spacing: 8
                        readonly property bool on: modelData.value === Dropdown.current
                        active: on
                        onClicked: Dropdown.pick(modelData.value)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: modelData.text; size: Tokens.fontSizeSmall; color: on ? Colors.primary : Colors.surfaceFg; Layout.fillWidth: true }
                            Label { visible: !!modelData.hint; text: modelData.hint || ""; size: Tokens.fontSizeMicro; dim: true; regular: true; Layout.fillWidth: true }
                        }
                        Glyph { visible: on; text: "󰄬"; size: Tokens.fontSizeIconSmall }
                    }
                }
                Label { visible: root.shown.length === 0; text: "nothing matches"; size: Tokens.fontSizeSmall; dim: true; regular: true; leftPadding: 8 }
            }
        }
    }
}
