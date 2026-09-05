import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
// A month on the desktop, today marked; the arrows browse, the title snaps back.
ColumnLayout {
    id: root
    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    spacing: 4
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.today = new Date() }
    function shift(n) { const d = new Date(year, month + n, 1); year = d.getFullYear(); month = d.getMonth() }
    readonly property var days: {
        const first = new Date(year, month, 1), start = (first.getDay() + 6) % 7
        const inMonth = new Date(year, month + 1, 0).getDate(), prev = new Date(year, month, 0).getDate()
        const out = []
        for (let i = 0; i < 42; i++) { const n = i - start + 1; out.push(n < 1 ? { d: prev + n, cur: false } : n > inMonth ? { d: n - inMonth, cur: false } : { d: n, cur: true }) }
        return out
    }
    RowLayout {
        Layout.fillWidth: true
        IconButton { glyph: "󰅁"; small: true; kind: "action"; onClicked: root.shift(-1) }
        Label { text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy"); size: Tokens.fontSizeTitle; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true
            MouseArea { anchors.fill: parent; onClicked: { root.year = root.today.getFullYear(); root.month = root.today.getMonth() } } }
        IconButton { glyph: "󰅂"; small: true; kind: "action"; onClicked: root.shift(1) }
    }
    GridLayout {
        columns: 7; rowSpacing: 2; columnSpacing: 2
        Layout.fillWidth: true; Layout.fillHeight: true
        Repeater { model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]; Label { required property string modelData; text: modelData; size: Tokens.fontSizeTiny; dim: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true } }
        Repeater {
            model: root.days
            Rectangle {
                required property var modelData
                readonly property bool isToday: modelData.cur && root.year === root.today.getFullYear() && root.month === root.today.getMonth() && modelData.d === root.today.getDate()
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: Tokens.rXs
                color: isToday ? Colors.primary : "transparent"
                Label { anchors.centerIn: parent; text: modelData.d; size: Tokens.fontSizeSmall; color: isToday ? Colors.primaryFg : modelData.cur ? Colors.surfaceFg : Tokens.alpha(Colors.surfaceVariantFg, 0.5) }
            }
        }
    }
}
