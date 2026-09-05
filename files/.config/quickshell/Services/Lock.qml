pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The lock screen's state, shared by every monitor's surface, and the PAM
// conversation. lock() engages the ext-session-lock; a correct password
// releases it. Nothing else does: there is deliberately no unlock() for IPC.
Singleton {
    id: root
    property bool locked: false
    property bool formOpen: false
    property string password: ""
    property bool busy: false
    property string status: ""
    property bool userListOpen: false
    property bool sessionListOpen: false
    readonly property var users: [Quickshell.env("USER") || "user"]
    property int userIndex: 0
    readonly property var sessions: []
    property int sessionIndex: 0
    property date now: new Date()
    property real lastInput: Date.now()
    readonly property bool demo: Quickshell.env("QS_LOCK_DEMO") === "1"
    // /etc/pam.d/quickshell (installed by ./greeter), else hyprlock's stack, else login
    property string pamConfig: "login"

    Timer { interval: 1000; running: root.locked; repeat: true; triggeredOnStart: true
        onTriggered: { root.now = new Date(); if (root.formOpen && !root.busy && !root.password.length && Date.now() - root.lastInput > 45000) root.formOpen = false } }

    function lock() {
        if (locked) return
        password = ""; status = ""; formOpen = false; busy = false
        now = new Date()
        locked = true
    }
    function open() { if (!formOpen) { formOpen = true; touch() } }
    function touch() { lastInput = Date.now() }
    function escapeIdle() { if (demo) unlockNow() }
    function power(action) { if (demo) { status = "demo: systemctl " + action; return } Proc.detach(["systemctl", action]) }
    function submit() {
        if (busy || !password.length) return
        busy = true; status = ""
        if (demo) { demoTimer.start(); return }
        pam.config = pamConfig
        if (!pam.start()) { busy = false; status = "could not start PAM" }
    }
    Timer { id: demoTimer; interval: 600; onTriggered: root.unlockNow() }
    function unlockNow() {
        busy = false; password = ""; status = ""
        locked = false
        formOpen = false
    }
    function fail(msg) { busy = false; password = ""; status = msg }

    PamContext {
        id: pam
        onPamMessage: { if (responseRequired) respond(root.password) }
        onCompleted: result => {
            if (result === PamResult.Success) root.unlockNow()
            else root.fail(result === PamResult.Failed ? "Wrong password" : "authentication error" + (pam.message ? ": " + pam.message : ""))
        }
    }
    Component.onCompleted: Proc.sh("for f in quickshell hyprlock login; do [ -f /etc/pam.d/$f ] && { echo $f; break; }; done", (c, out) => { const f = out.trim(); if (f) root.pamConfig = f })
}
