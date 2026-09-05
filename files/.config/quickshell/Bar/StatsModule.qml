import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// CPU · GPU · die temperature, as a three-bubble group; the middle one
// carries the accent, the ends turn red when hot.
RowLayout {
    id: root
    property var bar: null
    spacing: 0
    Bubble {
        bar: root.bar; corners: "capLeftM"; padL: 16; padR: 7; marginL: 7; interactive: false
        Label { text: "󰍛 " + Stats.cpu + "%"; size: Tokens.fontSizeBar; color: Colors.tertiary }
    }
    Bubble {
        bar: root.bar; corners: "none"; padL: 7; padR: 7; marginL: 0; interactive: false
        Label { text: "󰢮 " + Stats.gpu; size: Tokens.fontSizeBar; color: Stats.gpuTemp >= Stats.critical ? Colors.error : Colors.primary }
    }
    Bubble {
        bar: root.bar; corners: "capRightM"; padL: 7; padR: 14; marginL: 0; interactive: false
        Label { text: "󰔏 " + Stats.temp + "°C"; size: Tokens.fontSizeBar; color: Stats.temp >= Stats.critical ? Colors.error : Colors.tertiary }
    }
}
