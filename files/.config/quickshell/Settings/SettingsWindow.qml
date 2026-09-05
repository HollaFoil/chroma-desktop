import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// Settings: a window in the middle of the focused screen.
//     ┌──────────┬──────────────────────────────┐
//     │ Keybinds │  page title                  │
//     │ Windows  │  section                     │
//     │ Look     │   option ..... [control]     │
//     │ ...      │                              │
//     └──────────┴──────────────────────────────┘
// Pages are built when first shown and kept.
OverlayWindow {
    id: win
    placement: "center"
    property bool isOpen: false
    property int current: 0
    property var allowedScreens: Quickshell.screens
    open: isOpen
    onDismissed: isOpen = false

    readonly property var pages: [
        { title: "About PC",    glyph: "󰋽", group: "System",   comp: aboutComp },
        { title: "Keybinds",    glyph: "󰌌", group: "Desktop",  comp: keybindsComp },
        { title: "Windows",     glyph: "󱂬", group: "Desktop",  comp: windowsComp },
        { title: "Look",        glyph: "󰏘", group: "Desktop",  comp: lookComp },
        { title: "Input",       glyph: "󰌌", group: "Desktop",  comp: inputComp },
        { title: "Wallpapers",  glyph: "󰸉", group: "Desktop",  comp: wallpapersComp },
        { title: "Monitors",    glyph: "󰍹", group: "Hardware", comp: monitorsComp },
        { title: "Audio",       glyph: "󰕾", group: "Hardware", comp: audioComp },
        { title: "Wi-Fi",       glyph: "󰖩", group: "Network",  comp: wifiComp },
        { title: "Bluetooth",   glyph: "󰂯", group: "Network",  comp: bluetoothComp },
        { title: "Connections", glyph: "󰈀", group: "Network",  comp: connectionsComp },
        { title: "All options", glyph: "󰒓", group: "Advanced", comp: allComp }
    ]
    readonly property var groups: ["System", "Desktop", "Hardware", "Network", "Advanced"]
    Component { id: aboutComp; AboutPage {} }
    Component { id: keybindsComp; KeybindsPage { host: win } }
    Component { id: windowsComp; WindowsPage {} }
    Component { id: lookComp; LookPage {} }
    Component { id: inputComp; InputPage {} }
    Component { id: wallpapersComp; WallpapersPage {} }
    Component { id: monitorsComp; MonitorsPage {} }
    Component { id: audioComp; AudioPage {} }
    Component { id: wifiComp; WifiPage {} }
    Component { id: bluetoothComp; BluetoothPage {} }
    Component { id: connectionsComp; ConnectionsPage {} }
    Component { id: allComp; AllOptionsPage {} }

    property var built: ({})
    function show(page) {
        const focused = Hyprland.focusedMonitor
        const s = allowedScreens.find(sc => focused && sc.name === focused.name) ?? allowedScreens[0]
        if (s) screen = s
        if (page) {
            const i = pages.findIndex(p => p.title.toLowerCase().startsWith(page.toLowerCase()))
            if (i >= 0) current = i
        }
        const b = Object.assign({}, built); b[current] = true; built = b
        isOpen = true
    }
    function toggle() { if (isOpen) isOpen = false; else show("") }
    function select(i) { current = i; const b = Object.assign({}, built); b[i] = true; built = b }

    Card {
        slanted: false
        alpha: Tokens.aSettings
        minWidth: Tokens.settingsWidth
        padX: 14; padY: 12
        RowLayout {
            spacing: 0
            // nav
            ColumnLayout {
                Layout.preferredWidth: 150
                Layout.maximumWidth: 150
                Layout.alignment: Qt.AlignTop
                Layout.rightMargin: 12
                spacing: 2
                Repeater {
                    model: win.groups
                    ColumnLayout {
                        id: grp
                        required property string modelData
                        required property int index
                        readonly property var members: win.pages.map((p, i) => ({ p, i })).filter(x => x.p.group === grp.modelData)
                        visible: members.length > 0
                        spacing: 2
                        Label { text: grp.modelData; size: Tokens.fontSizeMicro; dim: true; leftPadding: 10; topPadding: grp.index === 0 ? 0 : 10; bottomPadding: 2 }
                        Repeater {
                            model: grp.members
                            ListRow {
                                required property var modelData
                                Layout.fillWidth: true
                                padX: 10; padY: 7
                                spacing: 12
                                readonly property bool on: win.current === modelData.i
                                color: on ? Tokens.alpha(Colors.primary, Tokens.aNavActive) : hovered ? Tokens.alpha(Colors.primary, Tokens.aHover) : "transparent"
                                onClicked: win.select(modelData.i)
                                Glyph { text: modelData.p.glyph; size: 17; color: on ? Colors.primary : Colors.primary; Layout.preferredWidth: 22 }
                                Label { text: modelData.p.title; color: on ? Colors.primary : Colors.surfaceFg; Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Tokens.alpha(Colors.outlineVariant, Tokens.aDivider) }
            // body
            Item {
                Layout.preferredWidth: 740
                Layout.minimumWidth: 740
                Layout.leftMargin: 12
                Layout.alignment: Qt.AlignTop
                implicitHeight: 620
                Repeater {
                    model: win.pages.length
                    Loader {
                        required property int index
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        active: win.built[index] === true
                        visible: win.current === index
                        sourceComponent: win.pages[index].comp
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                    }
                }
            }
        }
    }
}
