import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// The top-left menu: actions, then a row of power buttons.
ColumnLayout {
    id: root
    spacing: 2
    readonly property string home: Hypr.home
    readonly property var items: [
        { glyph: "󰀻", text: "Applications",  launcher: true },
        { glyph: "󰅌", text: "Clipboard",     clip: true },
        { glyph: "󰹑", text: "Screenshot",    run: 'grim -g "$(slurp)" - | wl-copy' },
        { glyph: "󰂚", text: "Notifications", notifs: true },
        { glyph: "󰘔", text: "Widgets",       widgets: true },
        { glyph: "󰒓", text: "Settings",      settings: true }
    ]
    readonly property var power: [
        { glyph: "󰌾", text: "Lock",      lock: true },
        { glyph: "󰤄", text: "Suspend",   run: "systemctl suspend" },
        { glyph: "󰍃", text: "Log out",   run: "hyprctl dispatch 'hl.dsp.exit()'" },
        { glyph: "󰜉", text: "Reboot",    run: "systemctl reboot" },
        { glyph: "󰐥", text: "Shut down", run: "systemctl poweroff", danger: true }
    ]
    function act(item) {
        Popups.close()
        if (item.settings) Overlays.openSettings("")
        else if (item.notifs) Overlays.toggleNotifs()
        else if (item.launcher) Overlays.toggleLauncher()
        else if (item.clip) Overlays.toggleClip()
        else if (item.lock) Lock.lock()
        else if (item.widgets) Desktop.editMode = !Desktop.editMode
        else Proc.detach(item.run)
    }

    Repeater {
        model: root.items
        ListRow {
            required property var modelData
            Layout.fillWidth: true
            padX: 10; padY: 6
            spacing: 12
            onClicked: root.act(modelData)
            Glyph { text: modelData.glyph; size: 17; Layout.preferredWidth: 22 }
            Label { text: modelData.text; Layout.fillWidth: true }
            Glyph { text: "󰅂"; size: Tokens.fontSizeSmall; color: Colors.surfaceVariantFg; visible: modelData.settings === true }
        }
    }
    Divider { Layout.fillWidth: true }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 4
        Repeater {
            model: root.power
            Rectangle {
                id: pb
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: col.implicitHeight + 8
                radius: Tokens.rSm
                color: pma.containsMouse ? Tokens.alpha(modelData.danger ? Colors.error : Colors.primary, Tokens.aHover) : "transparent"
                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                ColumnLayout {
                    id: col
                    anchors.centerIn: parent
                    spacing: 2
                    Glyph { text: pb.modelData.glyph; size: 17; Layout.alignment: Qt.AlignHCenter
                        color: pma.containsMouse ? (pb.modelData.danger ? Colors.error : Colors.primary) : Colors.surfaceVariantFg }
                    Label { text: pb.modelData.text; size: Tokens.fontSizeMicro; dim: true; Layout.alignment: Qt.AlignHCenter }
                }
                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.act(pb.modelData) }
            }
        }
    }
}
