import QtQuick
import qs.Theme
import qs.Widgets

// The Arch glyph in the corner; opens the launcher menu.
Bubble {
    id: root
    corners: "launcher"
    fullHeight: true
    padL: 15; padR: 35
    marginL: 0; marginR: 5
    onClicked: openPopup("launcher", "left")
    Glyph {
        text: "󰣇"
        size: 26
        color: root.hovered ? Colors.primary : Colors.tertiaryContainerFg
    }
}
