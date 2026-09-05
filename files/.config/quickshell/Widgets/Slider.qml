import QtQuick
import qs.Theme

// A horizontal slider. Controlled like Toggle: `value` comes from the owner,
// `moved` reports drags (throttled to one per 80 ms, plus one on release) and
// wheel steps. While the pointer is down the knob follows the hand, not the
// model, so a slow backend cannot make it stutter.
Item {
    id: root
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0
    property bool muted: false
    property int minWidth: 190
    readonly property bool dragging: ma.pressed
    signal moved(real value)

    property real _live: value
    property bool _pending: false
    onValueChanged: if (!ma.pressed) _live = value

    implicitWidth: minWidth
    implicitHeight: 14

    function frac() {
        return to > from ? Math.max(0, Math.min(1, (_live - from) / (to - from))) : 0
    }
    function clamp(v) {
        if (step > 0) v = Math.round(v / step) * step
        return Math.max(from, Math.min(to, v))
    }
    function setFromX(x) {
        _live = clamp(from + Math.max(0, Math.min(1, x / width)) * (to - from))
        if (throttle.running) { _pending = true } else { throttle.start(); moved(_live) }
    }
    Timer {
        id: throttle
        interval: 80
        onTriggered: if (root._pending) { root._pending = false; root.moved(root._live) }
    }

    Rectangle {
        id: trough
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 6; radius: Tokens.rPill
        color: Colors.surfaceContainerHighest
        Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.frac() * parent.width; height: 6; radius: Tokens.rPill
        color: root.muted ? Colors.surfaceVariantFg : Colors.primary
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
    }
    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, root.frac() * parent.width - width / 2))
        color: root.muted ? Colors.surfaceVariantFg
             : (ma.containsMouse || ma.pressed) ? Colors.primaryFixed : Colors.primary
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.topMargin: -4; anchors.bottomMargin: -4
        hoverEnabled: true
        enabled: root.enabled
        onPressed: mouse => root.setFromX(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.setFromX(mouse.x) }
        onReleased: { throttle.stop(); root._pending = false; root.moved(root._live) }
        onWheel: wheel => {
            const s = root.step > 0 ? root.step : (root.to - root.from) * 0.05
            root._live = root.clamp(root._live + (wheel.angleDelta.y > 0 ? s : -s))
            root.moved(root._live)
        }
    }
}
