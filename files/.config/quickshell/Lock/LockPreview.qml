import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Services

// A look at the lock screen without locking: an overlay on one screen that
// Escape closes (demo mode, so Enter "unlocks" it instead of asking PAM).
PanelWindow {
    id: win
    property bool isOpen: false
    visible: isOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-lockpreview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: Colors.surface
    QtObject {
        id: demoModel
        property bool formOpen: false
        property string password: ""
        property bool busy: false
        property string status: ""
        property bool userListOpen: false
        property bool sessionListOpen: false
        readonly property var users: [Quickshell.env("USER") || "user", "guest"]
        property int userIndex: 0
        readonly property var sessions: [{ name: "Hyprland" }, { name: "Hyprland (uwsm)" }]
        property int sessionIndex: 0
        property date now: new Date()
        function open() { formOpen = true }
        function touch() {}
        function escapeIdle() { win.isOpen = false }
        function power(a) { status = "demo: systemctl " + a }
        function submit() { if (!password.length) return; busy = true; done.start() }
    }
    Timer { id: done; interval: 600; onTriggered: { demoModel.busy = false; demoModel.password = ""; demoModel.status = "demo: would unlock"; } }
    Timer { interval: 1000; running: win.isOpen; repeat: true; onTriggered: demoModel.now = new Date() }
    LockScreen {
        anchors.fill: parent
        model: demoModel
        wallpaper: Colors.wallpaper
        greeter: win.greeterLook
    }
    property bool greeterLook: false
    function openForm() { demoModel.formOpen = true }
}
