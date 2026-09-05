import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Widgets

// Phase 0 widget gallery: one card on the primary monitor showing every shared
// widget, to tune Theme/Tokens.qml against waybar and barpop side by side.
ShellRoot {
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === "DP-2") ?? Quickshell.screens[0]
        anchors { top: true; left: true }
        margins { top: 60; left: 40 }
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-overlay"
        WlrLayershell.layer: WlrLayer.Overlay

        Card {
            id: card
            anchors.fill: parent
            minWidth: Tokens.popupMinWidth
            spacing: Tokens.sp2

            SectionHeader {
                glyph: "󰕾"; title: "Widget gallery"
                IconButton { glyph: "󰑐"; kind: "action"; small: true }
                IconButton { glyph: "󰅖"; kind: "danger"; small: true; onClicked: Qt.quit() }
            }
            Label { text: Colors.loaded ? "palette: " + Colors.path : "palette: fallback (run setwall)"; dim: true; regular: true; size: Tokens.fontSizeTiny; Layout.fillWidth: true }

            RowLayout {
                spacing: Tokens.sp2
                IconButton { glyph: "󰝟"; kind: "muted" }
                Slider { id: sl; value: 0.62; Layout.fillWidth: true; onMoved: v => value = v }
                Label { text: Math.round(sl.value * 100) + "%"; dim: true; size: Tokens.fontSizeSmall; Layout.preferredWidth: 44 }
                Pill { text: "Device ▾"; small: true }
            }
            Divider { Layout.fillWidth: true }

            RowLayout {
                spacing: Tokens.sp2
                Label { text: "Toggle"; Layout.fillWidth: true }
                Toggle { id: tg; checked: true; onToggled: v => checked = v }
            }
            RowLayout {
                spacing: Tokens.sp2
                Label { text: "Segmented"; Layout.fillWidth: true }
                Segmented { id: seg; model: ["dwindle", "master", "scrolling"]; current: 0; onPicked: i => current = i }
            }
            Entry { placeholder: "Search"; Layout.fillWidth: true }
            Divider { Layout.fillWidth: true }

            ListRow { Layout.fillWidth: true; active: true
                Glyph { text: "󰤨"; size: Tokens.fontSizeHeading; color: Colors.primary; Layout.preferredWidth: 22 }
                Label { text: "Home network"; size: Tokens.fontSizeSmall; color: Colors.primary; Layout.fillWidth: true }
                Label { text: "connected"; dim: true; size: Tokens.fontSizeTiny }
                IconButton { glyph: "󰅖"; kind: "danger"; small: true }
            }
            ListRow { Layout.fillWidth: true
                Glyph { text: "󰤢"; size: Tokens.fontSizeHeading; color: Colors.onSurfaceVariant; Layout.preferredWidth: 22 }
                Label { text: "Neighbour"; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
                Glyph { text: "󰌾"; size: Tokens.fontSizeSmall; color: Colors.onSurfaceVariant }
            }
            ListRow { Layout.fillWidth: true; accent: false
                Label { text: "Quiet hover row"; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
                IconButton { glyph: "󰑐"; kind: "action"; small: true; busy: true }
            }

            RowLayout {
                Label { text: "Revealer"; Layout.fillWidth: true }
                Pill { text: rev.open ? "hide" : "show"; small: true; on: rev.open; onClicked: rev.open = !rev.open }
            }
            Revealer { id: rev; Layout.fillWidth: true
                Scroller { Layout.fillWidth: true; maxHeight: 90
                    Repeater { model: 8
                        ListRow { Layout.fillWidth: true
                            required property int index
                            Label { text: "item " + (index + 1); size: Tokens.fontSizeSmall; Layout.fillWidth: true }
                        }
                    }
                }
            }
            StatusLine { text: "status line, and an "; error: false; Layout.fillWidth: true }
            StatusLine { text: "error line"; error: true; Layout.fillWidth: true }

            RowLayout {
                spacing: 4
                Repeater {
                    model: [Colors.primary, Colors.secondary, Colors.tertiary, Colors.error, Colors.primaryContainer, Colors.surface, Colors.surfaceContainerHigh, Colors.onSurface, Colors.outline]
                    Rectangle { required property color modelData; width: 22; height: 16; radius: 5; color: modelData; border.width: 1; border.color: Tokens.alpha(Colors.outline, 0.35)
                        Behavior on color { ColorAnimation { duration: Tokens.durSlow } } }
                }
            }
        }
    }
}
