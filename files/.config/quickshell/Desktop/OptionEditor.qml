import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// One widget option as its control, from the catalogue entry: a Toggle (bool),
// an Entry (text), a −/+ stepper (int) or the app picker (apps). The card under
// a widget in arrange mode and Settings › Widgets both build their option lists
// out of these.
ColumnLayout {
    id: root
    required property var option          // { key, label, type, def, min, max, zero }
    required property var widget          // the layout entry it belongs to
    required property string screenName
    property int fieldWidth: 220
    readonly property var value: Desktop.option(widget, option.key)
    function set(v) { Desktop.setOption(screenName, widget.id, option.key, v) }
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Label { text: root.option.label; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
        Toggle { visible: root.option.type === "bool"; checked: root.value === true; onToggled: v => root.set(v) }
        Entry { visible: root.option.type === "text"; Layout.preferredWidth: root.fieldWidth; text: String(root.value ?? ""); onEditingFinished: if (text !== String(root.value ?? "")) root.set(text) }
        RowLayout {
            id: step
            visible: root.option.type === "int"
            spacing: 2
            readonly property int n: Number(root.value) || 0
            readonly property int lo: root.option.min ?? 0
            readonly property int hi: root.option.max ?? 99
            IconButton { glyph: "󰍴"; kind: "action"; small: true; enabled: step.n > step.lo; onClicked: root.set(step.n - 1) }
            Label { text: step.n === 0 && root.option.zero ? root.option.zero : String(step.n); size: Tokens.fontSizeSmall; horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: 64 }
            IconButton { glyph: "󰐕"; kind: "action"; small: true; enabled: step.n < step.hi; onClicked: root.set(step.n + 1) }
        }
    }
    AppPicker {
        visible: root.option.type === "apps"
        Layout.fillWidth: true
        ids: root.option.type === "apps" ? String(root.value ?? "").split(",").map(s => s.trim()).filter(s => s) : []
        onChanged: l => root.set(l.join(", "))
    }
}
