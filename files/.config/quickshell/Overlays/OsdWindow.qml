import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// The OSD surface on one screen: shows Osd's state when this is the focused
// screen, bottom centre, sliding up.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    property var allScreens: Quickshell.screens
    // the focused screen, or the shell's first one when the focus is on an output the shell does not cover
    readonly property bool focusedHere: {
        const f = Hyprland.focusedMonitor
        if (f && allScreens.some(s => s.name === f.name)) return f.name === modelData.name
        return allScreens.length > 0 && allScreens[0].name === modelData.name
    }
    readonly property bool mine: Osd.visible && focusedHere
    visible: mine || fade.running
    color: "transparent"
    anchors { bottom: true }
    margins { bottom: 48 }
    implicitWidth: card.implicitWidth + 20
    implicitHeight: card.implicitHeight + 40
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    Card {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.mine ? 20 : 40
        opacity: win.mine ? 1 : 0
        Behavior on y { NumberAnimation { id: fade; duration: Tokens.durNormal; easing.type: Tokens.easing } }
        Behavior on opacity { NumberAnimation { duration: Tokens.durNormal } }
        slanted: false
        padX: 18; padY: 12
        RowLayout {
            spacing: 14
            Glyph { text: Osd.glyph; size: 20; color: Osd.muted ? Colors.surfaceVariantFg : Colors.primary; Layout.preferredWidth: 26 }
            Rectangle {
                Layout.preferredWidth: 220; Layout.preferredHeight: 6
                radius: Tokens.rPill
                color: Colors.surfaceContainerHighest
                Rectangle { width: parent.width * Osd.value; height: parent.height; radius: Tokens.rPill; color: Osd.muted ? Colors.surfaceVariantFg : Colors.primary
                    Behavior on width { NumberAnimation { duration: Tokens.durFast } } }
            }
            Label { text: Osd.muted && Osd.kind !== "brightness" ? "muted" : Math.round(Osd.value * 100) + "%"; size: Tokens.fontSizeSmall; dim: Osd.muted; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
        }
    }
}
