import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Theme

// The bar: one per screen, half-transparent surface that Hyprland blurs, with
// the modules as opaque bubbles. Layout follows the old waybar config:
// launcher and media left, workspaces and the bell centred, tray, stats,
// volume, network and the clock right.
PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: Tokens.barHeight
    color: Tokens.alpha(Colors.surface, Tokens.aBar)
    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top

    Behavior on color { ColorAnimation { duration: Tokens.durSlow } }

    RowLayout {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        spacing: 0
        LauncherModule { bar: bar }
        MediaModule { bar: bar }
    }
    RowLayout {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
        spacing: 0
        WorkspacesModule { bar: bar }
        BellModule { bar: bar }
    }
    RowLayout {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        spacing: 0
        TrayModule { bar: bar }
        StatsModule { bar: bar }
        VolumeModule { bar: bar }
        NetworkModule { bar: bar }
        ClockModule { bar: bar }
    }
}
