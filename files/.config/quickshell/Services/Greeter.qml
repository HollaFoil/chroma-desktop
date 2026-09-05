pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// The login screen's state (same shape as Lock, so LockScreen serves both)
// and the greetd conversation. Runs as the `greeter` user from a copy of this
// config at /etc/greetd/quickshell; the theme (colours, wallpaper) comes from
// $QS_GREETER_THEME, filled by greeter-sync on every setwall.
Singleton {
    id: root
    readonly property bool demo: Quickshell.env("QS_GREETER_DEMO") === "1"
    readonly property string themeDir: Quickshell.env("QS_GREETER_THEME") || "/etc/greetd/theme"
    readonly property string statePath: Quickshell.env("QS_GREETER_STATE") || "/var/lib/quickshell-greeter/state.json"
    readonly property string wallpaper: themeDir + "/background"

    property bool formOpen: false
    property string password: ""
    property bool busy: false
    property string status: ""
    property bool userListOpen: false
    property bool sessionListOpen: false
    property var users: []
    property int userIndex: 0
    property var sessions: []            // { name, cmd: [..], env: [..] }
    property int sessionIndex: 0
    property date now: new Date()
    property real lastInput: Date.now()
    property bool answered: false

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { root.now = new Date(); if (root.formOpen && !root.busy && !root.password.length && Date.now() - root.lastInput > 45000) root.formOpen = false } }

    function open() { if (!formOpen) { formOpen = true; touch() } }
    function touch() { lastInput = Date.now() }
    function escapeIdle() { if (demo) Qt.quit() }
    function power(action) { if (demo) { status = "demo: systemctl " + action; return } Proc.detach(["systemctl", action]) }
    function fail(msg) { busy = false; password = ""; status = msg; answered = false }
    function submit() {
        if (busy || !password.length || !users.length) return
        busy = true; status = ""; answered = false
        if (demo) { demoTimer.start(); return }
        if (!Greetd.available) { fail("greetd is not running"); return }
        Greetd.createSession(users[userIndex])
    }
    Timer { id: demoTimer; interval: 600; onTriggered: { root.busy = false; root.password = ""; root.status = "demo: would start " + (root.sessions[root.sessionIndex] || { name: "?" }).name + " as " + root.users[root.userIndex]; quitTimer.start() } }
    Timer { id: quitTimer; interval: 1500; onTriggered: Qt.quit() }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired) return
            if (root.answered) { Greetd.cancelSession(); root.fail((message || "").trim() || "unsupported prompt"); return }
            root.answered = true
            Greetd.respond(root.password)
        }
        function onAuthFailure(message) { root.fail("Wrong password") }
        function onError(e) { root.fail(String(e)) }
        function onReadyToLaunch() {
            const s = root.sessions[root.sessionIndex]
            root.saveState()
            Greetd.launch(s.cmd, s.env)
        }
    }

    // ── users, sessions, the remembered choice ──
    FileView { id: stateFile; path: root.statePath; printErrors: false; onLoaded: root.applyState(text()) }
    property var remembered: ({})
    function applyState(text) { try { remembered = JSON.parse(text) } catch (e) { remembered = {} } pickDefaults() }
    function saveState() { stateFile.setText(JSON.stringify({ user: users[userIndex], session: (sessions[sessionIndex] || {}).name })) }
    function pickDefaults() {
        const u = users.indexOf(remembered.user); if (u >= 0) userIndex = u
        let si = sessions.findIndex(s => s.name === remembered.session)
        if (si < 0) {
            // the plainest Hyprland entry (hyprland.desktop before hyprland-uwsm.desktop), else the first
            const hypr = sessions.map((s, i) => ({ s, i })).filter(x => /hyprland/i.test(x.s.name))
            si = hypr.length ? hypr.reduce((a, b) => a.s.name.length <= b.s.name.length ? a : b).i : 0
        }
        sessionIndex = Math.max(0, si)
    }
    function splitArgs(exec) { return exec.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g).map(a => a.replace(/^["']|["']$/g, "")) }
    Component.onCompleted: {
        Proc.sh("getent passwd | awk -F: '$3>=1000 && $3<60000 && $7 !~ /nologin|false/ {print $1}' | sort", (c, out) => {
            const list = out.split("\n").filter(x => x)
            root.users = list.length ? list : [Quickshell.env("USER") || "user"]
            root.pickDefaults()
        })
        Proc.sh("for f in /usr/share/wayland-sessions/*.desktop; do [ -f \"$f\" ] || continue; grep -qiE '^(Hidden|NoDisplay)=true' \"$f\" && continue; n=$(sed -n 's/^Name=//p' \"$f\" | head -1); e=$(sed -n 's/^Exec=//p' \"$f\" | head -1); d=$(sed -n 's/^DesktopNames=//p' \"$f\" | head -1); [ -n \"$e\" ] && printf '%s\\t%s\\t%s\\n' \"${n:-$(basename \"$f\" .desktop)}\" \"$e\" \"$d\"; done", (c, out) => {
            const list = out.split("\n").filter(x => x).map(l => {
                const [name, exec, desktops] = l.split("\t")
                const names = (desktops || "").split(";").filter(x => x)
                const env = ["XDG_SESSION_TYPE=wayland"]
                if (names.length) env.push("XDG_SESSION_DESKTOP=" + names[0], "XDG_CURRENT_DESKTOP=" + names.join(":"))
                return { name, cmd: root.splitArgs(exec), env }
            })
            root.sessions = list.length ? list : [{ name: "Hyprland", cmd: ["start-hyprland"], env: ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Hyprland", "XDG_CURRENT_DESKTOP=Hyprland"] }]
            root.pickDefaults()
        })
    }
}
