import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Lock
import qs.Services

// The login screen: greetd runs Hyprland as the `greeter` user with
// /etc/greetd/hyprland.lua, which runs this file from the copy of the config
// at /etc/greetd/quickshell. One surface per monitor, the UI on the largest.
//   QS_GREETER_THEME   theme dir (colors.json via QS_COLORS, background)
//   QS_GREETER_DEMO=1  no greetd: Enter reports what it would do, Esc quits
//   QS_SCREENS         limit to these outputs (a preview on one monitor)
ShellRoot {
    id: shell
    readonly property var onlyScreens: (Quickshell.env("QS_SCREENS") || "").split(",").filter(s => s.length > 0)
    readonly property var screens: Quickshell.screens.filter(s => onlyScreens.length === 0 || onlyScreens.indexOf(s.name) >= 0)
    readonly property var mainScreen: screens.reduce((a, b) => (a && a.width * a.height >= b.width * b.height) ? a : b, null)

    Variants {
        model: shell.screens
        PanelWindow {
            id: win
            required property var modelData
            readonly property bool isMain: modelData === shell.mainScreen
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.namespace: "qs-greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isMain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            LockScreen {
                anchors.fill: parent
                model: Greeter
                wallpaper: Greeter.wallpaper
                greeter: true
                showControls: win.isMain
                takesInput: win.isMain
            }
        }
    }
}
