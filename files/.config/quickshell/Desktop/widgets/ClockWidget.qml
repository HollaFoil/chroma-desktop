import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services
ColumnLayout {
    readonly property var w: parent.widget
    readonly property bool seconds: Desktop.option(w, "seconds") === true
    readonly property bool date: Desktop.option(w, "date") !== false
    spacing: 0
    SystemClock { id: clock; precision: SystemClock.Seconds }
    Item { Layout.fillHeight: true }
    Label { text: Qt.formatTime(clock.date, seconds ? "HH:mm:ss" : "HH:mm"); size: Math.min(72, Math.max(28, parent.height * 0.42)); font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
    Label { visible: date; text: Qt.formatDate(clock.date, "dddd, d MMMM"); size: Tokens.fontSizeTitle; dim: true; Layout.alignment: Qt.AlignHCenter }
    Item { Layout.fillHeight: true }
}
