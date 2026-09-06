import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Power: the power-profiles-daemon profile, what hypridle does when the desk
// goes quiet, what wakes the displays, and every battery upower knows about.
//   Power profile   pills from `powerprofilesctl list`, drivers as the hint
//   Idle            lock / displays off / suspend pickers + lock before sleep;
//                   every change rewrites ~/.config/hypr/hypridle.conf through
//                   its dotfiles symlink and restarts hypridle
//   Wake            the two Hyprland dpms options
//   Now             turn displays off, suspend, lock
//   Batteries       one read-only row per upower device with a charge
//   Advanced        where the file is, open it in the editor
PageBody {
    id: root
    title: "Power"
    subtitle: "Power profile, idle behaviour and batteries"
    headerItems: [ Pill { text: "󰑐  Refresh"; small: true; onClicked: root.refresh() } ]

    readonly property string idlePath: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"

    // ── power profile ─────────────────────────────────────────────────────
    property var profiles: []           // [{ name, cpuDriver, platformDriver }]
    property string activeProfile: ""
    property bool haveProfiles: true
    readonly property var activeInfo: profiles.find(p => p.name === activeProfile) ?? null
    function prettyProfile(n) { const t = n.replace(/-/g, " "); return t.charAt(0).toUpperCase() + t.slice(1) }
    function readProfiles() {
        Proc.run(["powerprofilesctl", "list"], (code, out) => {
            if (code !== 0) { haveProfiles = false; profiles = []; return }
            const list = []; let cur = null; let active = ""
            for (const raw of out.split("\n")) {
                const head = /^(\*?)\s*([a-z][a-z0-9-]*):\s*$/.exec(raw)
                if (head) { cur = { name: head[2], cpuDriver: "", platformDriver: "" }; list.push(cur); if (head[1] === "*") active = head[2]; continue }
                const kv = /^\s+(\w+):\s*(.*)$/.exec(raw)
                if (!kv || !cur) continue
                if (kv[1] === "CpuDriver") cur.cpuDriver = kv[2].trim()
                else if (kv[1] === "PlatformDriver") cur.platformDriver = kv[2].trim()
            }
            haveProfiles = true; profiles = list; activeProfile = active
        })
    }
    function setProfile(name) {
        Proc.run(["powerprofilesctl", "set", name], (code, out, err) => {
            if (code !== 0) { root.status = "could not set " + name + ": " + (err.trim().split("\n")[0] || "powerprofilesctl failed"); root.statusError = true }
            else { root.status = ""; root.statusError = false }
            readProfiles()
        })
    }

    // ── idle (hypridle.conf) ──────────────────────────────────────────────
    // general: the general block's lines as they are (before_sleep_cmd taken
    // out, it is the toggle); lock/dpms/suspend: seconds, 0 = no listener
    property var idle: ({ general: [], lock: 0, dpms: 0, suspend: 0, beforeSleep: false, beforeSleepCmd: "loginctl lock-session" })
    property bool idleLoaded: false
    readonly property var minuteChoices: [0, 1, 2, 5, 10, 15, 20, 30, 45, 60]
    function minutesText(sec) {
        if (sec <= 0) return "Never"
        if (sec % 60 !== 0) return sec + " seconds"
        const m = sec / 60
        return m === 1 ? "1 minute" : m + " minutes"
    }
    // the fixed list, plus whatever the file says if it is not one of them
    function timeoutModel(current) {
        const items = minuteChoices.map(m => ({ text: minutesText(m * 60), value: m * 60 }))
        if (current > 0 && !items.some(it => it.value === current)) { items.push({ text: minutesText(current), value: current }); items.sort((a, b) => a.value - b.value) }
        return items
    }
    function parseIdle(text) {
        const st = { general: [], lock: 0, dpms: 0, suspend: 0, beforeSleep: false, beforeSleepCmd: "loginctl lock-session" }
        let block = null, listener = null
        for (const raw of text.split("\n")) {
            const line = raw.trim()
            if (block === null) {
                if (/^general\s*\{/.test(line)) block = "general"
                else if (/^listener\s*\{/.test(line)) { block = "listener"; listener = { timeout: 0, cmd: "" } }
                continue
            }
            if (line === "}") {
                if (block === "listener") {
                    const c = listener.cmd
                    if (/dpms\s+off/.test(c)) st.dpms = listener.timeout
                    else if (/suspend|hibernate/.test(c)) st.suspend = listener.timeout
                    else if (/lock/.test(c)) st.lock = listener.timeout
                }
                block = null; listener = null
                continue
            }
            if (block === "general") {
                const m = /^before_sleep_cmd\s*=\s*(.*)$/.exec(line)
                if (m) { st.beforeSleep = true; if (m[1].trim()) st.beforeSleepCmd = m[1].trim(); continue }
                st.general.push(raw.replace(/\s+$/, ""))
            } else {
                let m
                if ((m = /^timeout\s*=\s*(\d+)/.exec(line))) listener.timeout = parseInt(m[1])
                else if ((m = /^on-timeout\s*=\s*(.*)$/.exec(line))) listener.cmd = m[1]
            }
        }
        while (st.general.length && st.general[st.general.length - 1] === "") st.general.pop()
        return st
    }
    function renderIdle(st) {
        const g = st.general.slice()
        if (st.beforeSleep) {
            const i = g.findIndex(l => /^\s*lock_cmd\s*=/.test(l))
            g.splice(i >= 0 ? i + 1 : g.length, 0, "    before_sleep_cmd = " + st.beforeSleepCmd)
        }
        let out = "# Written by Settings > Power (Idle). The pickers there own the listener\n"
                + "# blocks; the general block is carried over as it is, so lock_cmd and\n"
                + "# after_sleep_cmd can be edited here. Timeouts are seconds.\n\n"
        out += "general {\n" + g.join("\n") + "\n}\n"
        if (st.lock > 0) out += "\nlistener {\n    timeout = " + st.lock + "\n    on-timeout = loginctl lock-session\n}\n"
        if (st.dpms > 0) out += "\nlistener {\n    timeout = " + st.dpms + "\n    on-timeout = hyprctl dispatch dpms off\n    on-resume = hyprctl dispatch dpms on\n}\n"
        if (st.suspend > 0) out += "\nlistener {\n    timeout = " + st.suspend + "\n    on-timeout = systemctl suspend\n}\n"
        return out
    }
    function readIdle() {
        Proc.run(["cat", idlePath], (code, out) => {
            if (code !== 0) { idleLoaded = false; root.status = "could not read " + idlePath; root.statusError = true; return }
            idle = parseIdle(out); idleLoaded = true
        })
    }
    function changeIdle(key, value) {
        const st = Object.assign({}, idle); st[key] = value
        if (!st.general.length) st.general = ["    lock_cmd = loginctl lock-session", "    after_sleep_cmd = hyprctl dispatch dpms on"]
        idle = st
        Proc.run(["sh", "-c", 'printf %s "$QS_TEXT" > "$(readlink -f "$1")"', "sh", idlePath], (code, out, err) => {
            if (code !== 0) { root.status = "could not write hypridle.conf: " + err.trim(); root.statusError = true; return }
            Proc.sh("pkill -x hypridle; setsid hypridle >/dev/null 2>&1 &", () => { root.status = "hypridle restarted"; root.statusError = false })
        }, { QS_TEXT: renderIdle(st) })
    }
    readonly property string idleOrderNote: {
        if (!idleLoaded) return ""
        const l = idle.lock, d = idle.dpms, s = idle.suspend
        if (l > 0 && d > 0 && d < l) return "The displays go off before the screen locks."
        if (s > 0 && ((d > 0 && s < d) || (l > 0 && s < l))) return "Suspend comes before the lock or the displays going off."
        return ""
    }

    // ── batteries ─────────────────────────────────────────────────────────
    property var batteries: []          // [{ model, kind, level, state }]
    property bool batteriesLoaded: false
    function readBatteries() {
        Proc.sh('for d in $(upower -e); do echo "@@ $d"; upower -i "$d"; done', (code, out) => {
            const list = []
            for (const chunk of out.split("@@ ").slice(1)) {
                const lines = chunk.split("\n")
                const path = lines[0].trim()
                if (/DisplayDevice$/.test(path)) continue
                const dev = { model: "", kind: "", level: "", state: "", percentage: -1, ignore: false }
                for (const raw of lines.slice(1)) {
                    const kv = /^\s+([a-z-]+(?: [a-z-]+)*):\s*(.*)$/.exec(raw)
                    if (kv) {
                        const k = kv[1], v = kv[2].trim()
                        if (k === "model") dev.model = v
                        else if (k === "vendor" && !dev.model) dev.model = v
                        else if (k === "state") dev.state = v.replace(/-/g, " ")
                        else if (k === "battery-level") dev.level = v
                        else if (k === "percentage") { const p = /^(\d+(?:\.\d+)?)%/.exec(v); if (p) dev.percentage = parseFloat(p[1]); dev.ignore = v.indexOf("should be ignored") >= 0 }
                        continue
                    }
                    const kind = /^  ([a-z-]+)\s*$/.exec(raw)
                    if (kind) dev.kind = kind[1].replace(/-/g, " ")
                }
                if (dev.percentage < 0) continue
                if (!dev.model) dev.model = dev.kind ? dev.kind.charAt(0).toUpperCase() + dev.kind.slice(1) : path.split("/").pop()
                list.push(dev)
            }
            batteries = list; batteriesLoaded = true
        })
    }
    function batteryValue(b) {
        if (b.ignore && b.level && b.level !== "none") return b.level.charAt(0).toUpperCase() + b.level.slice(1).replace(/-/g, " ")
        return Math.round(b.percentage) + "%"
    }
    function batteryHint(b) { return [b.kind, b.state].filter(x => x && x !== "unknown").join(" · ") }

    function openIdleConf() {
        Overlays.settingsToggle()
        // TUI editors need a terminal; a GUI $EDITOR (codium) opens the file itself; nothing set falls back to xdg-open
        Proc.detach(["sh", "-c", 'e="${VISUAL:-${EDITOR:-}}"; case "${e##*/}" in "") exec xdg-open "$1";; vi|vim|nvim|nano|micro|hx|helix|emacs|kak|joe) exec kitty --title hypridle.conf -e $e "$1";; *) exec $e "$1";; esac', "sh", idlePath])
    }

    function refresh() { readProfiles(); readIdle(); readBatteries() }
    Component.onCompleted: refresh()

    Group {
        title: "Power profile"
        hint: root.haveProfiles ? "" : "power-profiles-daemon is not running, so there is nothing to choose."
        SettingRow {
            label: "Profile"
            hint: root.activeInfo ? [root.activeInfo.cpuDriver ? "CPU driver " + root.activeInfo.cpuDriver : "", root.activeInfo.platformDriver ? "platform driver " + root.activeInfo.platformDriver : ""].filter(x => x).join(" · ") : ""
            keywords: "performance balanced power saver powerprofilesctl cpu"
            enabled: root.haveProfiles && root.profiles.length > 0
            Segmented {
                model: root.profiles.map(p => root.prettyProfile(p.name))
                current: root.profiles.findIndex(p => p.name === root.activeProfile)
                onPicked: i => root.setProfile(root.profiles[i].name)
            }
        }
    }

    Group {
        title: "Idle"
        hint: root.idleOrderNote
        SettingRow {
            label: "Lock the screen after"
            hint: "Nothing touched for this long locks the session"
            keywords: "hypridle timeout lock screen idle"
            enabled: root.idleLoaded
            Picker { model: root.timeoutModel(root.idle.lock); current: root.idle.lock; onPicked: v => root.changeIdle("lock", v) }
        }
        SettingRow {
            label: "Turn displays off after"
            hint: "DPMS off; they come back on the first input"
            keywords: "hypridle timeout dpms displays off monitor screen idle"
            enabled: root.idleLoaded
            Picker { model: root.timeoutModel(root.idle.dpms); current: root.idle.dpms; onPicked: v => root.changeIdle("dpms", v) }
        }
        SettingRow {
            label: "Suspend after"
            hint: "systemctl suspend once the machine has sat idle this long"
            keywords: "hypridle timeout suspend sleep idle"
            enabled: root.idleLoaded
            Picker { model: root.timeoutModel(root.idle.suspend); current: root.idle.suspend; onPicked: v => root.changeIdle("suspend", v) }
        }
        SettingRow {
            label: "Lock before sleep"
            hint: "Lock the session as the machine suspends, so it wakes to the lock screen"
            keywords: "before_sleep_cmd lock suspend sleep"
            enabled: root.idleLoaded
            Toggle { checked: root.idle.beforeSleep; onToggled: v => root.changeIdle("beforeSleep", v) }
        }
    }

    Group {
        title: "Wake"
        hint: "What brings the displays back once they are off"
        OptionRow { name: "misc:mouse_move_enables_dpms" }
        OptionRow { name: "misc:key_press_enables_dpms" }
    }

    Group {
        title: "Now"
        SettingRow {
            label: "Turn displays off"
            hint: "Any key or mouse movement wakes them"
            keywords: "dpms screen monitor off now"
            clickable: true
            onClicked: Proc.detach(["hyprctl", "dispatch", "dpms", "off"])
        }
        SettingRow {
            label: "Suspend"
            hint: "systemctl suspend"
            keywords: "sleep suspend now"
            clickable: true
            onClicked: { Overlays.settingsToggle(); Proc.detach(["systemctl", "suspend"]) }
        }
        SettingRow {
            label: "Lock"
            hint: "loginctl lock-session"
            keywords: "lock screen now"
            clickable: true
            onClicked: { Overlays.settingsToggle(); Proc.detach(["loginctl", "lock-session"]) }
        }
    }

    Group {
        title: "Batteries"
        hint: "Everything upower reports a charge for, wireless mice included"
        SettingRow { visible: root.batteriesLoaded && root.batteries.length === 0 && hit; label: "No batteries"; hint: "No device with a battery is connected"; keywords: "battery upower" }
        Repeater {
            model: root.batteries
            SettingRow {
                required property var modelData
                label: modelData.model
                hint: root.batteryHint(modelData)
                keywords: "battery charge upower " + modelData.kind
                value: root.batteryValue(modelData)
            }
        }
    }

    Group {
        title: "Advanced"
        advanced: true
        SettingRow { label: "Idle config"; hint: "Rewritten from the Idle group above; the general block survives edits"; keywords: "hypridle conf file path"; value: root.idlePath.replace(Quickshell.env("HOME"), "~") }
        SettingRow {
            label: "Open hypridle.conf"
            hint: "In $EDITOR, or whatever opens .conf files"
            keywords: "edit hypridle conf editor"
            clickable: true
            onClicked: root.openIdleConf()
        }
    }
}
