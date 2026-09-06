import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Date & Time: the system clock and the shell's own clock.
//   Time      now · set automatically (NTP) · time zone · synchronised
//   Clock     24/12-hour · seconds · date in the bar        (Prefs clock.*)
//   Advanced  RTC in local time · universal time
// Backed by timedatectl: `show -p NTP -p Timezone -p NTPSynchronized -p LocalRTC`
// for the state, `list-timezones` for the choices, and `set-ntp`, `set-timezone`,
// `set-local-rtc` to change things (systemd asks polkit for the right by itself).
PageBody {
    id: root
    title: "Date & Time"
    subtitle: "Clock and time zone"
    status: "reading…"

    property date now: new Date()
    property bool ntp: false
    property bool synced: false
    property bool localRtc: false
    property string timezone: ""
    property var zones: []           // [{ text, value }] from `timedatectl list-timezones`
    readonly property bool h24: Prefs.get("clock.24h", true)
    readonly property bool showSeconds: Prefs.get("clock.seconds", true)

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    function timeFormat() { return (h24 ? "HH:mm" : "h:mm") + (showSeconds ? ":ss" : "") + (h24 ? "" : " AP") }
    function pad(n) { return String(n).padStart(2, "0") }
    function utcText(d) {
        return d.getUTCFullYear() + "-" + pad(d.getUTCMonth() + 1) + "-" + pad(d.getUTCDate()) + "  " + pad(d.getUTCHours()) + ":" + pad(d.getUTCMinutes()) + ":" + pad(d.getUTCSeconds()) + " UTC"
    }
    function parseKv(out) {
        const kv = {}
        for (const line of out.split("\n")) { const i = line.indexOf("="); if (i > 0) kv[line.slice(0, i).trim()] = line.slice(i + 1).trim() }
        return kv
    }
    function refresh() {
        Proc.run(["timedatectl", "show", "-p", "NTP", "-p", "Timezone", "-p", "NTPSynchronized", "-p", "LocalRTC"], (code, out, err) => {
            if (code !== 0) { root.status = "timedatectl: " + (err.trim() || "exit " + code); root.statusError = true; return }
            const kv = parseKv(out)
            root.ntp = kv.NTP === "yes"
            root.synced = kv.NTPSynchronized === "yes"
            root.localRtc = kv.LocalRTC === "yes"
            root.timezone = kv.Timezone || ""
            if (root.status === "reading…") root.status = ""
        })
    }
    function loadZones() {
        Proc.run(["timedatectl", "list-timezones"], (code, out) => {
            const list = out.split("\n").map(s => s.trim()).filter(s => s.length > 0)
            root.zones = list.map(z => ({ text: z.replace(/_/g, " "), value: z }))
        })
    }
    // run a timedatectl verb, tell the status line how it went, re-read the state
    function apply(args, done) {
        root.statusError = false
        root.status = "applying…"
        Proc.run(["timedatectl"].concat(args), (code, out, err) => {
            if (code !== 0) { root.status = (err.trim() || out.trim() || "timedatectl failed (exit " + code + ")"); root.statusError = true }
            else root.status = done || ""
            refresh()
        })
    }
    Component.onCompleted: { refresh(); loadZones() }

    Group {
        title: "Time"
        hint: "The system clock, shared by every program"
        SettingRow {
            label: "Now"
            hint: root.timezone.length > 0 ? root.timezone.replace(/_/g, " ") : ""
            keywords: "current date time today"
            value: Qt.formatDateTime(root.now, "dddd d MMMM yyyy") + "   " + Qt.formatDateTime(root.now, root.timeFormat())
        }
        SettingRow {
            label: "Set time automatically"
            hint: "Keep the clock right over the network (NTP)"
            keywords: "ntp network time sync automatic"
            Toggle { checked: root.ntp; onToggled: v => root.apply(["set-ntp", v ? "true" : "false"], v ? "network time on" : "network time off") }
        }
        SettingRow {
            label: "Time zone"
            hint: "Where the clock is; daylight saving follows the zone"
            keywords: "timezone region city utc offset"
            Picker {
                model: root.zones
                current: root.timezone
                placeholder: root.zones.length ? "Choose a zone…" : "reading…"
                minWidth: 220
                onPicked: v => root.apply(["set-timezone", v], "time zone set to " + v.replace(/_/g, " "))
            }
        }
        SettingRow {
            label: "Synchronised"
            hint: root.ntp ? "Whether the clock has been checked against a time server since boot" : "Turn on automatic time to synchronise"
            keywords: "ntp synced status"
            value: root.synced ? "yes" : "no"
        }
    }

    Group {
        title: "Clock"
        hint: "How the bar and the desktop show the time"
        SettingRow {
            label: "Format"
            hint: "24-hour or 12-hour with AM/PM"
            keywords: "24 hour 12 hour am pm clock format"
            Segmented { model: ["24-hour", "12-hour"]; current: root.h24 ? 0 : 1; onPicked: i => Prefs.set("clock.24h", i === 0) }
        }
        SettingRow {
            label: "Show seconds"
            hint: "Tick every second in the bar clock"
            keywords: "seconds clock bar"
            Toggle { checked: root.showSeconds; onToggled: v => Prefs.set("clock.seconds", v) }
        }
        SettingRow {
            label: "Show date in the bar"
            hint: "Weekday and date next to the time"
            keywords: "date bar clock weekday calendar"
            Toggle { checked: Prefs.get("clock.date", false); onToggled: v => Prefs.set("clock.date", v) }
        }
    }

    Group {
        title: "Advanced"
        advanced: true
        SettingRow {
            label: "RTC in local time"
            hint: "Keep the hardware clock in local time instead of UTC; only for dual boots with Windows"
            keywords: "rtc hardware clock local utc windows dual boot"
            Toggle { checked: root.localRtc; onToggled: v => root.apply(["set-local-rtc", v ? "true" : "false"], v ? "hardware clock now in local time" : "hardware clock now in UTC") }
        }
        SettingRow {
            label: "Universal time"
            hint: "The same moment in UTC"
            keywords: "utc universal coordinated time gmt"
            value: root.utcText(root.now)
        }
    }
}
