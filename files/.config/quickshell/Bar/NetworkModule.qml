import QtQuick
import qs.Theme
import qs.Widgets
import qs.Services

// One glyph: connected or not. Click for the network panel.
Bubble {
    id: root
    corners: "mirror"
    onClicked: openPopup("network", "right")
    Glyph {
        text: Net.anyConnected ? "󰖩" : "󰖪"
        size: Tokens.barIconSize
        color: Net.anyConnected ? Colors.surfaceFg : Colors.error
    }
}
