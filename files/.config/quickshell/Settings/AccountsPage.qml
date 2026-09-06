import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Accounts: you, this machine and its sessions.
//   You              avatar + name · full name · password · login shell · avatar hint
//   This machine     hostname · pretty name · chassis · machine ID
//   Sessions         one row per logind session (id, user, seat, tty, state)
//   Session actions  lock now · log out
//   Login (adv.)     greetd autologin, read from /etc/greetd/config.toml
// Backed by `getent passwd`, `hostnamectl --json=short` / `set-hostname`,
// `loginctl list-sessions` + `show-session`, `loginctl lock-session` and
// `hyprctl dispatch exit`. Anything that asks for the password (chfn, passwd,
// chsh) runs in a kitty window after this one closes.
PageBody {
    id: root
    title: "Accounts"
    subtitle: "You, this machine and its sessions"
    status: "reading…"

    property string username: ""
    property string fullName: ""
    property string shell: ""
    property string home: Quickshell.env("HOME") || ""
    property bool hasFace: false
    property string staticHost: ""
    property string prettyHost: ""
    property string chassis: ""
    property string machineId: ""
    property var sessions: []            // [{ id, name, seat, tty, state, type, class }]
    property string autologin: ""        // "", "on", "off", "unreadable"
    property string autologinUser: ""
    readonly property string thisSession: Quickshell.env("XDG_SESSION_ID") || ""

    function loadUser() {
        Proc.sh("getent passwd \"$(id -un)\"; echo @@; test -f \"$HOME/.face\" && echo face", (code, out) => {
            const p = out.split("@@").map(s => s.trim())
            const f = (p[0] || "").split(":")
            root.username = f[0] || ""
            root.fullName = (f[4] || "").split(",")[0]
            root.shell = f[6] || ""
            root.hasFace = (p[1] || "") === "face"
            nameEntry.text = root.fullName
            if (root.status === "reading…") root.status = ""
        })
    }
    function loadHost() {
        Proc.run(["hostnamectl", "--json=short"], (code, out, err) => {
            if (code !== 0) { root.status = "hostnamectl: " + (err.trim() || "exit " + code); root.statusError = true; return }
            let j = {}
            try { j = JSON.parse(out) } catch (e) { j = {} }
            root.staticHost = j.StaticHostname || j.Hostname || ""
            root.prettyHost = j.PrettyHostname || ""
            root.chassis = j.Chassis || ""
            root.machineId = j.MachineID || ""
            hostEntry.text = root.staticHost
            prettyEntry.text = root.prettyHost
        })
    }
    function loadSessions() {
        Proc.sh("for s in $(loginctl list-sessions --no-legend | awk '{print $1}'); do loginctl show-session \"$s\" -p Id -p Name -p Seat -p TTY -p State -p Type -p Class; echo @@; done", (code, out) => {
            const list = []
            for (const block of out.split("@@")) {
                const kv = {}
                for (const line of block.split("\n")) { const i = line.indexOf("="); if (i > 0) kv[line.slice(0, i).trim()] = line.slice(i + 1).trim() }
                if (kv.Id) list.push({ id: kv.Id, name: kv.Name || "", seat: kv.Seat || "", tty: kv.TTY || "", state: kv.State || "", type: kv.Type || "", cls: kv.Class || "" })
            }
            root.sessions = list
        })
    }
    function loadLogin() {
        // grep exits 0 when found, 1 when not, 2 when the file cannot be read
        Proc.sh("grep -q '^\\[initial_session\\]' /etc/greetd/config.toml; c=$?; echo $c; echo @@; sed -n '/^\\[initial_session\\]/,/^\\[/p' /etc/greetd/config.toml 2>/dev/null | sed -n 's/^user *= *\"\\(.*\\)\"/\\1/p' | head -1", (code, out) => {
            const p = out.split("@@").map(s => s.trim())
            root.autologin = p[0] === "0" ? "on" : p[0] === "1" ? "off" : "unreadable"
            root.autologinUser = p[1] || ""
        })
    }
    function reload() { loadUser(); loadHost(); loadSessions(); loadLogin() }
    Component.onCompleted: reload()

    // run a hostnamectl verb, report, re-read
    function hostApply(args, done) {
        root.statusError = false
        root.status = "applying…"
        Proc.run(["hostnamectl"].concat(args), (code, out, err) => {
            if (code !== 0) { root.status = err.trim() || out.trim() || "hostnamectl failed (exit " + code + ")"; root.statusError = true }
            else root.status = done
            loadHost()
        })
    }
    // things that ask for the password get a terminal of their own
    function inTerminal(title, script, env) {
        Overlays.settingsToggle()
        const cmd = ["kitty", "--title", title]
        if (env) { cmd.push("env"); for (const k in env) cmd.push(k + "=" + env[k]) }
        Proc.detach(cmd.concat(["sh", "-c", script + "; echo; echo done; sleep 1"]))
    }

    Group {
        title: "You"
        // identity: avatar, full name, username (not a SettingRow: the picture sits on the left)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            spacing: 12
            visible: SettingsSearch.matches(root.fullName + " " + root.username + " avatar user")
            Item {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                Rectangle { anchors.fill: parent; radius: 20; color: Tokens.alpha(Colors.primary, Tokens.aActive); visible: !root.hasFace }
                Glyph { anchors.centerIn: parent; text: "󰀄"; size: 22; visible: !root.hasFace }
                Image {
                    id: face
                    anchors.fill: parent
                    visible: root.hasFace
                    source: root.hasFace ? "file://" + root.home + "/.face" : ""
                    sourceSize.width: 80; sourceSize.height: 80
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: root.hasFace
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: faceMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                }
                Rectangle { id: faceMask; anchors.fill: parent; radius: 20; visible: false; layer.enabled: true }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label { text: root.fullName.length > 0 ? root.fullName : root.username; size: Tokens.fontSizeTitle; Layout.fillWidth: true }
                Label { text: root.username + (root.fullName.length > 0 ? "" : "  ·  no full name set"); size: Tokens.fontSizeTiny; dim: true; regular: true; Layout.fillWidth: true }
            }
        }
        SettingRow {
            label: "Full name"
            hint: "Shown on the lock and login screens; chfn asks for your password in a terminal"
            keywords: "name gecos chfn real name"
            Entry {
                id: nameEntry
                Layout.preferredWidth: 220
                placeholder: "Your name"
                onEditingFinished: {
                    const t = text.trim()
                    if (t.length === 0 || t === root.fullName) { text = root.fullName; return }
                    root.inTerminal("Change name", "chfn -f \"$QS_NAME\"", { QS_NAME: t })
                }
            }
        }
        SettingRow {
            label: "Password"
            hint: "Change it in a terminal; the current one is asked first"
            keywords: "password passwd change"
            clickable: true
            onClicked: root.inTerminal("Change password", "passwd")
        }
        SettingRow {
            label: "Login shell"
            hint: "The shell terminals start; chsh asks for your password"
            keywords: "shell fish bash zsh chsh"
            value: root.shell
            clickable: true
            onClicked: root.inTerminal("Change shell", "chsh")
        }
        SettingRow {
            label: "Avatar"
            hint: "Put a square image at ~/.face; the greeter and this page pick it up"
            keywords: "avatar picture face photo image"
            value: root.hasFace ? "~/.face" : "none yet"
        }
    }

    Group {
        title: "This machine"
        SettingRow {
            label: "Hostname"
            hint: "The name on the network; letters, digits and hyphens"
            keywords: "hostname computer name network"
            Entry {
                id: hostEntry
                Layout.preferredWidth: 220
                placeholder: "hostname"
                onEditingFinished: {
                    const t = text.trim()
                    if (t.length === 0 || t === root.staticHost) { text = root.staticHost; return }
                    root.hostApply(["set-hostname", "--static", "--transient", t], "hostname is now " + t)
                }
            }
        }
        SettingRow {
            label: "Pretty name"
            hint: "A free-form name for people; empty to clear"
            keywords: "pretty hostname display name"
            Entry {
                id: prettyEntry
                Layout.preferredWidth: 220
                placeholder: "none"
                onEditingFinished: {
                    const t = text.trim()
                    if (t === root.prettyHost) return
                    root.hostApply(["set-hostname", "--pretty", t], t.length > 0 ? "pretty name is now " + t : "pretty name cleared")
                }
            }
        }
        SettingRow { label: "Chassis"; hint: "What systemd thinks this machine is"; keywords: "chassis desktop laptop vm"; value: root.chassis }
        SettingRow { label: "Machine ID"; hint: "/etc/machine-id, unique to this installation"; keywords: "machine id"; value: root.machineId }
    }

    Group {
        title: "Sessions"
        hint: "Everyone logged in right now, from logind"
        trailing: [ IconButton { glyph: "󰑐"; kind: "action"; small: true; onClicked: root.loadSessions() } ]
        SettingRow { visible: hit && root.sessions.length === 0; label: "No sessions"; hint: "loginctl listed nothing"; keywords: "session" }
        Repeater {
            model: root.sessions
            SettingRow {
                required property var modelData
                label: "Session " + modelData.id + "  ·  " + modelData.name
                hint: [modelData.cls + (modelData.type ? " / " + modelData.type : ""), modelData.seat ? "seat " + modelData.seat : "", modelData.tty].filter(s => s.length > 0).join("  ·  ")
                      + (modelData.id === root.thisSession ? "  ·  this one" : "")
                keywords: "session user seat tty " + modelData.name + " " + modelData.state
                value: modelData.state
            }
        }
    }

    Group {
        title: "Session actions"
        hint: "These act at once, without asking again"
        SettingRow {
            label: "Lock now"
            hint: "Lock the screen (loginctl lock-session)"
            keywords: "lock screen"
            clickable: true
            onClicked: { Overlays.settingsToggle(); Proc.detach(["loginctl", "lock-session"]) }
        }
        SettingRow {
            label: "Log out"
            hint: "Ends this Hyprland session and every program in it, right away"
            keywords: "logout exit quit session end"
            clickable: true
            onClicked: Proc.detach(["hyprctl", "dispatch", "exit"])
        }
    }

    Group {
        title: "Login"
        hint: "greetd, the login manager"
        advanced: true
        SettingRow {
            label: "Autologin"
            hint: "change with ./greeter install [--no-autologin] in the dotfiles"
            keywords: "autologin greetd initial_session login manager greeter"
            value: root.autologin === "on" ? "on" + (root.autologinUser ? "  (" + root.autologinUser + ")" : "")
                 : root.autologin === "off" ? "off"
                 : root.autologin === "unreadable" ? "unknown: /etc/greetd/config.toml is not readable" : ""
        }
    }
}
