import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Storage: every block device lsblk knows about, sorted into three groups.
//   Mounted        one row per mounted filesystem with a usage bar
//                  ┌ / ───────────────────────────────────────────────┐
//                  │ /dev/nvme1n1p2 · btrfs · Samsung SSD · also /home │
//                  │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
//                  │ 117.8 / 1859.0 GiB (6%)                           │
//                  removable ones get unmount / power-off buttons
//   Other volumes  partitions with a filesystem that are not mounted,
//                  a Mount pill each (udisksctl, polkit asks if it must)
//   Disks          the drives: model, size, bus, SSD or HDD (advanced)
// Swap, zram and loop devices are left out.
PageBody {
    id: root
    title: "Storage"
    subtitle: "Disks and mounts"
    headerItems: [ Pill { text: "󰑐  Refresh"; small: true; onClicked: root.refresh() } ]

    property var mounted: []        // [{ label, hint, path, diskPath, used, size, frac, pct, removable, key }]
    property var others: []         // [{ label, hint, path, removable, key }]
    property var disks: []          // [{ label, hint, size, key }]
    property bool loaded: false

    function gib(n) { return ((n || 0) / Math.pow(2, 30)).toFixed(1) }
    function fmtSize(n) {
        if (!n) return ""
        if (n >= Math.pow(2, 40)) return (n / Math.pow(2, 40)).toFixed(2) + " TiB"
        if (n >= Math.pow(2, 30)) return gib(n) + " GiB"
        return Math.round(n / Math.pow(2, 20)) + " MiB"
    }
    function skip(node) { return node.type === "loop" || /^(zram|loop|ram)\d*$/.test(node.name || "") || node.fstype === "swap" }
    function mounts(node) { return (node.mountpoints || []).filter(m => m && m !== "[SWAP]") }
    // "/" first, then the shortest path: the one people know the volume by
    function primaryMount(list) { return list.indexOf("/") >= 0 ? "/" : list.slice().sort((a, b) => a.length - b.length)[0] }

    function refresh() {
        Proc.sh("lsblk -J -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,LABEL,RM,HOTPLUG,MODEL,FSUSED,FSSIZE,FSAVAIL,PATH,TRAN; echo @@; grep . /sys/block/*/queue/rotational 2>/dev/null", (code, out, err) => {
            const parts = out.split("@@")
            let data = null
            try { data = JSON.parse(parts[0]) } catch (e) { data = null }
            if (!data || !Array.isArray(data.blockdevices)) { root.status = "lsblk failed: " + ((err || "").trim().split("\n")[0] || "no output"); root.statusError = true; return }
            const rotational = {}
            for (const line of (parts[1] || "").split("\n")) { const m = /\/sys\/block\/([^/]+)\/queue\/rotational:(\d)/.exec(line); if (m) rotational[m[1]] = m[2] === "1" }

            const fs = [], other = [], drives = []
            const walk = (node, disk) => {
                if (skip(node)) return
                if (node.type === "disk") {
                    disk = node
                    const parts = (node.children || []).filter(c => c.type === "part").length
                    const kind = rotational[node.name] === undefined ? "" : rotational[node.name] ? "HDD" : "SSD"
                    drives.push({
                        key: node.path, label: (node.model || node.name).trim(), size: fmtSize(node.size),
                        hint: [node.path, (node.tran || "").toUpperCase(), kind, parts ? parts + (parts === 1 ? " partition" : " partitions") : "", (node.rm || node.hotplug) ? "removable" : ""].filter(x => x).join(" · ")
                    })
                }
                const removable = !!(node.rm || node.hotplug || (disk && (disk.rm || disk.hotplug)))
                const model = (disk && disk.model ? disk.model : "").trim()
                const mp = mounts(node)
                if (node.fstype && mp.length) {
                    const main = primaryMount(mp)
                    const rest = mp.filter(m => m !== main).sort()
                    const size = node.fssize || node.size || 0, used = node.fsused || 0
                    fs.push({
                        key: node.path, path: node.path, diskPath: disk ? disk.path : node.path,
                        label: node.label || main,
                        hint: [node.label ? main : "", node.path, node.fstype, model, rest.length ? "also " + rest.slice(0, 3).join(", ") + (rest.length > 3 ? " +" + (rest.length - 3) : "") : ""].filter(x => x).join(" · "),
                        used, size, frac: size ? used / size : 0, pct: size ? Math.round(used / size * 100) : 0, removable, main
                    })
                } else if (node.fstype && (node.type !== "disk" || !(node.children || []).length)) {   // a partition, or a whole disk formatted without a table
                    other.push({
                        key: node.path, path: node.path, label: node.label || node.name, removable,
                        hint: [node.path, node.fstype, fmtSize(node.size), model].filter(x => x).join(" · ")
                    })
                }
                for (const c of (node.children || [])) walk(c, disk)
            }
            for (const d of data.blockdevices) walk(d, null)
            fs.sort((a, b) => a.main === "/" ? -1 : b.main === "/" ? 1 : a.main.localeCompare(b.main))
            mounted = fs; others = other; disks = drives; loaded = true
            if (root.statusError) { root.status = ""; root.statusError = false }
        })
    }
    // udisksctl talks to udisks over D-Bus; polkit asks for a password itself when it must
    function udisks(args, verb) {
        root.status = verb + "…"; root.statusError = false
        Proc.run(["udisksctl"].concat(args), (code, out, err) => {
            const line = (code === 0 ? out : err).trim().split("\n").filter(l => l.length).pop() || (code === 0 ? verb + " done" : "udisksctl failed")
            root.status = line.replace(/^Object .*?: /, ""); root.statusError = code !== 0
            refresh()
        })
    }
    function mount(path) { udisks(["mount", "-b", path], "mounting " + path) }
    function unmount(path) { udisks(["unmount", "-b", path], "unmounting " + path) }
    function powerOff(v) {
        root.status = "powering off " + v.diskPath + "…"; root.statusError = false
        Proc.run(["sh", "-c", 'udisksctl unmount -b "$1" && udisksctl power-off -b "$2"', "sh", v.path, v.diskPath], (code, out, err) => {
            root.status = code === 0 ? v.diskPath + " powered off, safe to unplug" : ((err || out).trim().split("\n").pop() || "power-off failed")
            root.statusError = code !== 0
            refresh()
        })
    }
    Component.onCompleted: refresh()

    Group {
        title: "Mounted"
        SettingRow { visible: root.loaded && root.mounted.length === 0 && hit; label: "Nothing mounted"; hint: "lsblk reports no mounted filesystem"; keywords: "mount" }
        Repeater {
            model: root.mounted
            SettingRow {
                id: fsRow
                required property var modelData
                label: modelData.label
                hint: modelData.hint
                keywords: "mount filesystem partition usage space " + modelData.path + " " + modelData.main
                wide: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Colors.surfaceContainerHighest
                        Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
                        Rectangle {
                            width: Math.max(fsRow.modelData.frac > 0 ? 6 : 0, parent.width * Math.min(1, fsRow.modelData.frac))
                            height: 6; radius: 3
                            color: fsRow.modelData.pct > 90 ? Colors.error : Colors.primary
                            Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
                            Behavior on width { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easing } }
                        }
                    }
                    Label {
                        text: root.gib(fsRow.modelData.used) + " / " + root.gib(fsRow.modelData.size) + " GiB (" + fsRow.modelData.pct + "%)"
                        size: Tokens.fontSizeTiny; dim: true; regular: true
                        color: fsRow.modelData.pct > 90 ? Colors.error : Colors.surfaceVariantFg
                    }
                }
                IconButton { visible: fsRow.modelData.removable; glyph: ""; kind: "action"; small: true; onClicked: root.unmount(fsRow.modelData.path) }
                IconButton { visible: fsRow.modelData.removable; glyph: "󰐥"; kind: "danger"; small: true; onClicked: root.powerOff(fsRow.modelData) }
            }
        }
    }

    Group {
        title: "Other volumes"
        hint: "Filesystems that are not mounted. Mounting puts them under /run/media."
        visible: (!SettingsSearch.active && root.others.length > 0) || hitCount > 0
        Repeater {
            model: root.others
            SettingRow {
                id: otherRow
                required property var modelData
                label: modelData.label
                hint: modelData.hint
                keywords: "mount unmounted volume partition udisks " + modelData.path
                Pill { text: "Mount"; small: true; onClicked: root.mount(otherRow.modelData.path) }
            }
        }
    }

    Group {
        title: "Disks"
        advanced: true
        Repeater {
            model: root.disks
            SettingRow {
                required property var modelData
                label: modelData.label
                hint: modelData.hint
                keywords: "disk drive ssd hdd nvme sata usb " + modelData.key
                value: modelData.size
            }
        }
    }
}
