import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// The shell itself: which bar modules are shown, the on-screen display, where
// the clock's format lives, the launcher and clipboard keys, and the lock
// screen. Everything here is a Prefs key (bar.*, osd.*) or an action.
PageBody {
    id: root
    title: "Shell"
    subtitle: "The bar, the on-screen display and the launchers"

    function keys(id) { const k = Binds.keysOf(id).map(c => Binds.prettyCombo(c)); return k.length ? k.join(", ") : "not bound" }
    function tilde(p) { const h = Quickshell.env("HOME"); return h && p.startsWith(h) ? "~" + p.slice(h.length) : p }

    Group {
        title: "Bar modules"
        hint: "The launcher, workspaces, bell and clock are always on"
        Repeater {
            model: [
                { key: "bar.media",   label: "Media",            hint: "Spotify transport, its volume and the track; only while something is loaded" },
                { key: "bar.record",  label: "Recording button", hint: "A dot that turns red and counts while the screen is recorded" },
                { key: "bar.tray",    label: "Tray",             hint: "Status icons of running apps; only while there are any" },
                { key: "bar.stats",   label: "System stats",     hint: "CPU load, GPU load and die temperature" },
                { key: "bar.volume",  label: "Volume",           hint: "Output level; click for the audio panel, scroll to change" },
                { key: "bar.network", label: "Network",          hint: "Connected or not; click for the network panel" }
            ]
            SettingRow {
                id: modRow
                required property var modelData
                label: modelData.label
                hint: modelData.hint
                keywords: "bar module show hide"
                Toggle { checked: Prefs.get(modRow.modelData.key, true); onToggled: v => Prefs.set(modRow.modelData.key, v) }
            }
        }
    }

    Group {
        title: "On-screen display"
        hint: "The small bar at the bottom of the screen when a key changes something"
        SettingRow {
            label: "Show volume and brightness changes"
            hint: "Also the microphone mute"
            keywords: "osd popup"
            Toggle { checked: Prefs.get("osd.enabled", true); onToggled: v => Prefs.set("osd.enabled", v) }
        }
        SettingRow {
            label: "Hide after"
            hint: "How long it stays once the keys are still"
            keywords: "osd timeout duration"
            enabled: Prefs.get("osd.enabled", true)
            Picker {
                model: [{ text: "1 s", value: 1000 }, { text: "1.5 s", value: 1500 }, { text: "2 s", value: 2000 }, { text: "3 s", value: 3000 }]
                current: Prefs.get("osd.timeout", 1500)
                minWidth: 90
                onPicked: v => Prefs.set("osd.timeout", v)
            }
        }
    }

    Group {
        title: "Clock"
        SettingRow {
            label: "Format and seconds are in Date & Time"
            hint: "12 or 24 hour, seconds, and whether the date shows first"
            keywords: "clock time 24h seconds date"
            clickable: true
            onClicked: Overlays.openSettings("datetime")
        }
    }

    Group {
        title: "Launcher & clipboard"
        hint: "Change the keys on the Keybinds page"
        SettingRow {
            label: "App launcher"
            hint: "Search and start apps"
            keywords: "keybind shortcut run"
            value: Binds.revision, root.keys("app.launcher")
            clickable: true
            onClicked: Overlays.openSettings("keybinds")
        }
        SettingRow {
            label: "Clipboard history"
            hint: "Pick something copied earlier"
            keywords: "keybind shortcut cliphist paste"
            value: Binds.revision, root.keys("util.clipboard")
            clickable: true
            onClicked: Overlays.openSettings("keybinds")
        }
        SettingRow {
            label: "Clear clipboard history"
            hint: "Forgets everything cliphist has kept"
            keywords: "wipe delete"
            clickable: true
            onClicked: Proc.run(["cliphist", "wipe"], (code, out, err) => {
                root.statusError = code !== 0
                root.status = code === 0 ? "Clipboard history cleared" : "cliphist failed: " + (err.trim() || "exit " + code)
            })
        }
    }

    Group {
        title: "Lock screen"
        SettingRow {
            label: "Preview the lock screen"
            hint: "A look at it on the shell's first screen, nothing is locked"
            keywords: "lock demo look"
            clickable: true
            onClicked: { Overlays.settingsToggle(); Proc.detach(["qs", "ipc", "call", "lock", "preview", "false"]) }
        }
        SettingRow {
            label: "Lock now"
            hint: "Your password unlocks it"
            keywords: "lock session"
            clickable: true
            onClicked: Proc.detach(["loginctl", "lock-session"])
        }
    }

    Group {
        title: "Advanced"
        advanced: true
        SettingRow {
            label: "Restart the shell"
            hint: "The bar and this window close for a moment and come back"
            keywords: "quickshell reload systemctl"
            clickable: true
            onClicked: Proc.detach(["systemctl", "--user", "restart", "quickshell"])
        }
        SettingRow {
            label: "Prefs file"
            hint: "Where this window's choices about the shell are saved"
            keywords: "json path state"
            value: root.tilde(Prefs.path)
        }
    }
}
