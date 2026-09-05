import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets

// A month. Arrows or scrolling move it; the title snaps back to today.
ColumnLayout {
    id: root
    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    spacing: Tokens.sp1
    function shift(n) { const d = new Date(year, month + n, 1); year = d.getFullYear(); month = d.getMonth() }
    function reset() { year = today.getFullYear(); month = today.getMonth() }
    readonly property var days: {
        const first = new Date(year, month, 1)
        const start = (first.getDay() + 6) % 7          // Monday first
        const inMonth = new Date(year, month + 1, 0).getDate()
        const prev = new Date(year, month, 0).getDate()
        const out = []
        for (let i = 0; i < 42; i++) {
            const n = i - start + 1
            if (n < 1) out.push({ d: prev + n, cur: false })
            else if (n > inMonth) out.push({ d: n - inMonth, cur: false })
            else out.push({ d: n, cur: true })
        }
        return out
    }
    MouseArea {
        Layout.fillWidth: true
        Layout.fillHeight: true
        z: -1
        onWheel: wheel => root.shift(wheel.angleDelta.y < 0 ? 1 : -1)
    }
    RowLayout {
        Layout.fillWidth: true
        IconButton { glyph: "󰅁"; small: true; kind: "action"; onClicked: root.shift(-1) }
        Label { text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy"); size: Tokens.fontSizeTitle; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.reset() } }
        IconButton { glyph: "󰅂"; small: true; kind: "action"; onClicked: root.shift(1) }
    }
    GridLayout {
        columns: 7
        rowSpacing: 2; columnSpacing: 2
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Label { required property string modelData; text: modelData; size: Tokens.fontSizeTiny; dim: true; horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: 32 }
        }
        Repeater {
            model: root.days
            Rectangle {
                required property var modelData
                readonly property bool isToday: modelData.cur && root.year === root.today.getFullYear() && root.month === root.today.getMonth() && modelData.d === root.today.getDate()
                Layout.preferredWidth: 32; Layout.preferredHeight: 26
                radius: Tokens.rXs
                color: isToday ? Colors.primary : "transparent"
                Label { anchors.centerIn: parent; text: modelData.d; size: Tokens.fontSizeSmall; color: isToday ? Colors.primaryFg : modelData.cur ? Colors.surfaceFg : Tokens.alpha(Colors.surfaceVariantFg, 0.5) }
            }
        }
    }
}
