import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Notifications: do-not-disturb and the centre, how long toasts stay and
// where they appear, then one row per app that has notified so a chatty one
// can be kept to the centre. Toast and history settings live in Prefs
// (toast.*, notifs.*); do-not-disturb is Notifs' own runtime state.
PageBody {
    id: root
    title: "Notifications"
    subtitle: "Toasts, do-not-disturb and per-app rules"

    readonly property var muted: Prefs.get("notifs.muted", [])
    // every app in the history plus the muted ones (a muted app stays listed after its notifications are cleared)
    readonly property var apps: {
        const seen = {}
        for (const e of Notifs.items) seen[e.app] = true
        for (const a of muted) seen[a] = true
        return Object.keys(seen).sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }))
    }
    function setMuted(app, on) {
        const list = muted.filter(a => a !== app)
        if (on) list.push(app)
        Prefs.set("notifs.muted", list.sort())
    }
    readonly property var durations: [
        { text: "3 s", value: 3000 }, { text: "5 s", value: 5000 }, { text: "10 s", value: 10000 },
        { text: "15 s", value: 15000 }, { text: "30 s", value: 30000 }
    ]
    readonly property var corners: ["top-left", "top-right", "bottom-left", "bottom-right"]
    readonly property string toastScreen: Prefs.get("toast.screen", "focused")
    readonly property var screenChoices: {
        const list = [{ text: "Focused screen", value: "focused", hint: "wherever the pointer is" }]
        for (const s of Quickshell.screens) list.push({ text: s.name, value: s.name, hint: s.width + "×" + s.height })
        if (!list.some(it => it.value === toastScreen)) list.push({ text: toastScreen, value: toastScreen, hint: "not connected; the focused screen is used" })
        return list
    }
    function tilde(p) { const h = Quickshell.env("HOME"); return h && p.startsWith(h) ? "~" + p.slice(h.length) : p }

    Group {
        title: "Do not disturb"
        SettingRow {
            label: "Do not disturb"
            hint: "Keep every notification in the centre and show no toasts"
            keywords: "dnd quiet silence"
            Toggle { checked: Notifs.dnd; onToggled: v => Notifs.dnd = v }
        }
        SettingRow {
            label: "Open the notification centre"
            hint: "Also on the bell in the bar"
            keywords: "panel list"
            clickable: true
            onClicked: { Overlays.settingsToggle(); Overlays.toggleNotifs() }
        }
        SettingRow {
            label: "In the centre"
            hint: "What is waiting there now"
            keywords: "count clear all"
            Label { text: Notifs.count === 0 ? "nothing" : Notifs.count + (Notifs.count === 1 ? " notification" : " notifications"); size: Tokens.fontSizeSmall; dim: true; regular: true }
            IconButton { glyph: "󰎟"; kind: "danger"; small: true; enabled: Notifs.count > 0; onClicked: Notifs.clearAll() }
        }
    }

    Group {
        title: "Toasts"
        hint: "The cards that slide in when something arrives; critical ones stay until dismissed"
        SettingRow {
            label: "Duration"
            hint: "How long a normal notification stays on screen"
            keywords: "timeout seconds"
            Picker { model: root.durations; current: Prefs.get("toast.timeout.normal", 10000); onPicked: v => Prefs.set("toast.timeout.normal", v) }
        }
        SettingRow {
            label: "Low-priority duration"
            hint: "For notifications an app marks as low urgency"
            keywords: "timeout seconds"
            Picker { model: root.durations; current: Prefs.get("toast.timeout.low", 5000); onPicked: v => Prefs.set("toast.timeout.low", v) }
        }
        SettingRow {
            label: "Show on"
            hint: "The screen toasts appear on"
            keywords: "monitor output display"
            Picker { model: root.screenChoices; current: root.toastScreen; minWidth: 160; onPicked: v => Prefs.set("toast.screen", v) }
        }
        SettingRow {
            label: "Corner"
            hint: "Where on that screen they stack"
            keywords: "position top bottom left right"
            Segmented {
                model: ["↖ Top left", "↗ Top right", "↙ Bottom left", "↘ Bottom right"]
                current: root.corners.indexOf(Prefs.get("toast.position", "top-right"))
                onPicked: i => Prefs.set("toast.position", root.corners[i])
            }
        }
    }

    Group {
        title: "Apps"
        hint: "Apps that have notified recently; muted ones only appear in the centre"
        SettingRow {
            visible: hit && root.apps.length === 0
            label: "Nothing has notified yet"
            hint: "Apps show up here after their first notification"
        }
        Repeater {
            model: root.apps
            SettingRow {
                id: appRow
                required property var modelData
                readonly property bool isMuted: root.muted.indexOf(modelData) >= 0
                label: modelData
                hint: isMuted ? "Only in the centre" : "Toasts and the centre"
                keywords: "mute app toasts"
                Label { text: "Show toasts"; size: Tokens.fontSizeSmall; dim: true; regular: true }
                Toggle { checked: !appRow.isMuted; onToggled: v => root.setMuted(appRow.modelData, !v) }
            }
        }
    }

    Group {
        title: "Advanced"
        advanced: true
        SettingRow {
            label: "Keep in history"
            hint: "The oldest are dropped past this many"
            keywords: "limit cap count"
            Picker {
                model: [{ text: "50", value: 50 }, { text: "100", value: 100 }, { text: "200", value: 200 }, { text: "500", value: 500 }]
                current: Prefs.get("notifs.history", 200)
                minWidth: 90
                onPicked: v => Prefs.set("notifs.history", v)
            }
        }
        SettingRow {
            label: "Clear history"
            hint: "Removes everything from the centre and the saved list"
            keywords: "delete forget"
            clickable: true
            onClicked: Notifs.clearAll()
        }
        SettingRow {
            label: "History file"
            hint: "Where the centre is saved between restarts"
            keywords: "state json path"
            value: root.tilde(Notifs.statePath)
        }
    }
}
