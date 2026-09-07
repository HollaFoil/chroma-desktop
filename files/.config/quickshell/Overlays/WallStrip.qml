import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// Pick a wallpaper from a looping strip of previews: the centre one large
// and full-bright, neighbours shrinking and dimming outwards, the list
// wrapping around so scrolling never hits an end. No chrome; the filename
// sits under the centre image.
//     ←/→  h/l  scroll   move        Enter / Space / click centre   apply (setwall)
//     click a side image             jump to it                     Esc / click away   close
PanelWindow {
    id: win
    property bool isOpen: false
    property var allowedScreens: Quickshell.screens
    readonly property var walls: Wallpapers.files
    property int target: 0
    property real pos: 0
    Behavior on pos { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    property var afterRelease: null

    readonly property real centerW: 560
    readonly property real sideScale: 0.55
    readonly property int sideCount: 3
    readonly property real gap: 28
    readonly property real radius: 18

    visible: isOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // see Widgets/OverlayWindow: a click anywhere outside clears the grab and closes the strip
    HyprlandFocusGrab { id: grab; windows: [win]; onCleared: win.isOpen = false }
    onIsOpenChanged: grab.active = isOpen

    function show() {
        const focused = Hyprland.focusedMonitor
        const s = allowedScreens.find(sc => focused && sc.name === focused.name) ?? allowedScreens[0]
        if (s) screen = s
        Wallpapers.refresh()
        const i = Math.max(0, walls.indexOf(Wallpapers.current))
        target = i; pos = i
        isOpen = true
        scope.forceActiveFocus()
    }
    function toggle() { if (isOpen) isOpen = false; else show() }
    function move(d) { target += d; pos = target }
    function index() { const n = walls.length; return n ? ((target % n) + n) % n : 0 }
    function apply() { if (walls.length) Wallpapers.apply(walls[index()]) }

    // slot geometry: offset 0 is the centre, each step out scales by sideScale
    function slotInt(offset) {
        const w = centerW * Math.pow(sideScale, Math.abs(offset))
        let x = width / 2
        const step = offset > 0 ? 1 : -1
        for (let k = 1; k <= Math.abs(offset); k++) {
            const prev = centerW * Math.pow(sideScale, k - 1), cur = centerW * Math.pow(sideScale, k)
            x += step * (prev / 2 + gap + cur / 2)
        }
        return { cx: x, w: w, h: w * 9 / 16 }
    }
    function slot(offset) {
        const lo = Math.floor(offset), t = offset - lo
        const a = slotInt(lo), b = slotInt(lo + 1)
        const w = a.w + (b.w - a.w) * t, h = a.h + (b.h - a.h) * t
        return { x: a.cx + (b.cx - a.cx) * t - w / 2, y: height / 2 - h / 2, w: w, h: h }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Escape || k === Qt.Key_Q) win.afterRelease = "close"
            else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_J || k === Qt.Key_Tab) win.move(1)
            else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_K || k === Qt.Key_Backtab) win.move(-1)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { win.apply(); win.afterRelease = "close" }
            event.accepted = true
        }
        Keys.onReleased: event => { if (win.afterRelease) { win.afterRelease = null; win.isOpen = false } event.accepted = true }

        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, Tokens.aBackdrop) }
        MouseArea {
            anchors.fill: parent
            onClicked: win.isOpen = false
            onWheel: wheel => win.move((wheel.angleDelta.y + wheel.angleDelta.x) < 0 ? 1 : -1)
        }
        Repeater {
            // slots around the centre, outer ones first so the centre draws on top
            model: win.isOpen && win.walls.length ? (2 * (win.sideCount + 2) + 1) : 0
            Item {
                id: slotItem
                required property int index
                readonly property int j: Math.round(win.pos) + (index - (win.sideCount + 2))
                readonly property real f: j - win.pos
                readonly property real edge: Math.min(1, Math.max(0, win.sideCount + 1 - Math.abs(f)))
                readonly property var g: win.slot(f)
                readonly property int wallIndex: { const n = win.walls.length; return ((j % n) + n) % n }
                x: g.x; y: g.y; width: g.w; height: g.h
                z: -Math.abs(f)
                visible: edge > 0
                opacity: (0.75 + 0.25 * Math.max(0, 1 - Math.abs(f))) * edge
                Rectangle {
                    anchors.fill: parent
                    radius: win.radius * Math.sqrt(width / win.centerW)
                    color: Colors.surfaceContainerHigh
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: "file://" + win.walls[slotItem.wallIndex]
                        sourceSize.width: 640; sourceSize.height: 360
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const off = slotItem.j - win.target
                        if (off === 0) { win.apply(); win.isOpen = false } else win.move(off)
                    }
                    onWheel: wheel => win.move((wheel.angleDelta.y + wheel.angleDelta.x) < 0 ? 1 : -1)
                }
            }
        }
        Label {
            readonly property int nearest: Math.round(win.pos)
            readonly property var c: win.slotInt(0)
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height / 2 + c.h / 2 + 18
            text: win.walls.length ? win.walls[((nearest % win.walls.length) + win.walls.length) % win.walls.length].split("/").pop() : ""
            size: Tokens.fontSizeSmall
            opacity: 0.95 * Math.max(0, 1 - 2 * Math.abs(win.pos - nearest))
        }
    }
}
