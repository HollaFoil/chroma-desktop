import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services
// CPU, GPU, temperature, memory and one disk as bars.
ColumnLayout {
    id: root
    readonly property var w: parent.widget
    spacing: 8
    Component.onCompleted: { const d = Desktop.option(w, "disk"); if (d) Stats.diskMount = d }
    component Bar: ColumnLayout {
        property string glyph; property string name; property string value; property real frac; property bool hot: false
        Layout.fillWidth: true
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            Glyph { text: glyph; size: 15; color: hot ? Colors.error : Colors.tertiary; Layout.preferredWidth: 20 }
            Label { text: name; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
            Label { text: value; size: Tokens.fontSizeSmall; dim: true }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 5; radius: 3; color: Colors.surfaceContainerHighest
            Rectangle { width: parent.width * Math.max(0, Math.min(1, frac)); height: parent.height; radius: 3; color: hot ? Colors.error : Colors.primary
                Behavior on width { NumberAnimation { duration: Tokens.durSlow } } } }
    }
    Bar { glyph: "󰍛"; name: "CPU"; value: Stats.cpu + "%"; frac: Stats.cpu / 100 }
    Bar { glyph: "󰢮"; name: "GPU"; value: Stats.gpu + (Stats.gpuTemp ? "  ·  " + Stats.gpuTemp + "°C" : ""); frac: (parseInt(Stats.gpu) || 0) / 100; hot: Stats.gpuTemp >= Stats.critical; visible: Stats.gpuAvailable }
    Bar { glyph: "󰔏"; name: "CPU temperature"; value: Stats.temp + "°C"; frac: Stats.temp / 100; hot: Stats.temp >= Stats.critical; visible: Stats.hwmonPath !== "" }
    Bar { glyph: "󰘚"; name: "Memory"; value: Stats.gib(Stats.memUsed) + " / " + Stats.gib(Stats.memTotal) + " GiB"; frac: Stats.memUsed / Stats.memTotal }
    Bar { glyph: "󰋊"; name: "Disk " + Stats.diskMount; value: Stats.gib(Stats.diskUsed) + " / " + Stats.gib(Stats.diskTotal) + " GiB"; frac: Stats.diskUsed / Stats.diskTotal }
    Item { Layout.fillHeight: true }
}
