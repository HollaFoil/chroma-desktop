import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// This monitor's workspaces. Hyprland has one global set, so each monitor
// owns a bank of five (1-5, 11-15, 21-25; hypr/state/monitors.json says
// which) and the bar relabels the bank 1-5, which is also what SUPER+1..5
// types. The five are always drawn so they work as buttons while empty; any
// other workspace that lands on this monitor is appended as a dot.
Bubble {
    id: root
    corners: "round"
    padL: 5; padR: 5
    marginL: 5; marginR: 5
    interactive: false
    spacing: 0

    readonly property string monitorName: bar && bar.screen ? bar.screen.name : ""
    property var wsHome: ({})
    FileView {
        path: Hypr.hyprDir + "/state/monitors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.wsHome = JSON.parse(text()).ws_home ?? {} } catch (e) { root.wsHome = {} } }
    }
    readonly property var hyprMonitor: Hyprland.monitors.values.find(m => m.name === root.monitorName) ?? null
    readonly property var bank: {
        const ids = Object.keys(wsHome).filter(k => wsHome[k] === monitorName).map(Number).sort((a, b) => a - b)
        if (ids.length) return ids
        const base = hyprMonitor ? hyprMonitor.id * 10 : 0
        return [1, 2, 3, 4, 5].map(i => base + i)
    }
    readonly property var here: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name === root.monitorName)
    readonly property var ids: bank.concat(here.map(w => w.id).filter(id => bank.indexOf(id) < 0).sort((a, b) => a - b))
    function wsById(id) { return Hyprland.workspaces.values.find(w => w.id === id) ?? null }

    onScrolled: d => Hypr.dispatchLua('hl.dsp.focus({ workspace = "' + (d < 0 ? "m+1" : "m-1") + '" })')

    Repeater {
        model: root.ids
        Rectangle {
            id: btn
            required property int modelData
            readonly property var ws: root.wsById(modelData)
            readonly property bool active: ws !== null && ws.active
            readonly property bool urgent: ws !== null && ws.urgent
            readonly property bool wide: active || ma.containsMouse
            readonly property string label: root.bank.indexOf(modelData) >= 0 ? String(modelData % 10) : "•"
            Layout.fillHeight: true
            Layout.topMargin: 4; Layout.bottomMargin: 4
            Layout.leftMargin: 3; Layout.rightMargin: 3
            implicitWidth: wide ? 50 : txt.implicitWidth + 10
            radius: 16
            color: urgent ? Colors.error : active ? Colors.primary : ma.containsMouse ? Colors.tertiary : Colors.surfaceContainerHighest
            Behavior on implicitWidth { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.InOutCubic } }
            Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
            Label {
                id: txt
                anchors.centerIn: parent
                text: btn.label
                size: Tokens.fontSizeBar
                color: btn.wide || btn.urgent ? Colors.scrim : "transparent"
                Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.dispatchLua('hl.dsp.focus({ workspace = "' + btn.modelData + '" })')
                onWheel: wheel => root.scrolled(wheel.angleDelta.y)
            }
        }
    }
}
