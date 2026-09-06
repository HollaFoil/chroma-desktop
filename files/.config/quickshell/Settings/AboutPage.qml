import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// About this PC: the fastfetch view, as a page. Each section is a Group of
// read-only rows; a value too long for the right-hand column (the CPU string,
// a disk line) wraps under its label instead.
//   System    OS · kernel · host · uptime · packages · shell · locale · IP
//   Desktop   Hyprland · quickshell · matugen · Qt · theme / icons / cursor / font · wallpaper · palette
//   Hardware  board · BIOS · CPU · GPUs · memory · swap · disks · displays · audio · bluetooth
PageBody {
    id: root
    title: "About"
    subtitle: "This machine, its software and hardware"
    property var sections: []      // [{ title, rows: [[key, value]] }]; value "@palette" renders the swatches
    property string hoverCaption: "hover a swatch for its role and hex"
    readonly property var swatches: [["primary", Colors.primary], ["secondary", Colors.secondary], ["tertiary", Colors.tertiary], ["error", Colors.error],
                                     ["primary container", Colors.primaryContainer], ["surface", Colors.surface], ["surface container high", Colors.surfaceContainerHigh],
                                     ["on surface", Colors.surfaceFg], ["outline", Colors.outline]]
    headerItems: [ Pill { text: "󰆏  Copy"; small: true; onClicked: root.copy() } ]
    status: "reading…"

    function gib(n) { return ((n || 0) / Math.pow(2, 30)).toFixed(1) + " GiB" }
    function duration(ms) {
        let s = Math.floor(ms / 1000); const d = Math.floor(s / 86400); s %= 86400; const h = Math.floor(s / 3600); s %= 3600; const m = Math.floor(s / 60)
        return (d ? d + "d " : "") + h + "h " + m + "m"
    }
    function collect() {
        const ffModules = "OS:Kernel:Uptime:Packages:Shell:Locale:LocalIp:Loadavg:Board:BIOS:CPU:GPU:Memory:Swap:Disk:Display:Sound:Bluetooth"
        Proc.run(["fastfetch", "--format", "json", "--structure", ffModules], (code, out) => {
            let ff = {}
            try { for (const m of JSON.parse(out)) if (m.result !== undefined) ff[m.type] = m.result } catch (e) { ff = {} }
            const haveFf = code === 0 && Object.keys(ff).length > 0
            Proc.sh("hyprctl -j version; echo @@; qs --version; echo @@; matugen --version; echo @@; qtpaths6 --qt-version; echo @@; gsettings get org.gnome.desktop.interface gtk-theme; echo @@; gsettings get org.gnome.desktop.interface icon-theme; echo @@; gsettings get org.gnome.desktop.interface cursor-theme; echo @@; gsettings get org.gnome.desktop.interface cursor-size; echo @@; gsettings get org.gnome.desktop.interface font-name; echo @@; $SHELL --version 2>/dev/null | head -1", (c2, out2) => {
                const p = out2.split("@@").map(s => s.trim())
                let hv = {}; try { hv = JSON.parse(p[0]) } catch (e) {}
                const gs = i => (p[i] || "").replace(/^'|'$/g, "")
                root.sections = [
                    { title: "System", rows: systemRows(ff, p[9] || "") },
                    { title: "Desktop", rows: [
                        ["Hyprland", hv.version ? hv.version + "  (" + (hv.tag || "") + ", " + String(hv.commit || "").slice(0, 8) + ")" : ""],
                        ["Session", (Quickshell.env("XDG_SESSION_TYPE") || "?") + " · " + (Quickshell.env("XDG_CURRENT_DESKTOP") || "?")],
                        ["Shell", (p[1] || "").replace("Quickshell ", "quickshell ")],
                        ["matugen", (p[2] || "").replace("matugen ", "")],
                        ["Qt", p[3] || ""],
                        ["GTK theme", gs(4)], ["Icons", gs(5)], ["Cursor", gs(6) + " " + gs(7) + "px"], ["Font", gs(8)],
                        ["Wallpaper", Wallpapers.current.split("/").pop()],
                        ["Palette", "@palette"]
                    ].filter(r => r[1] !== "") },
                    { title: "Hardware", rows: hardwareRows(ff) }
                ]
                root.status = haveFf ? "" : "install fastfetch for board, BIOS, GPU, disk and display details"
            })
        })
    }
    function systemRows(ff, shellVersion) {
        const rows = []
        const o = ff.OS || {}; if (o.prettyName || o.name) rows.push(["OS", [o.prettyName || o.name, o.version].filter(x => x).join(" ")])
        const k = ff.Kernel || {}; if (k.release) rows.push(["Kernel", k.release + " " + (k.architecture || "")])
        if (ff.Uptime) rows.push(["Uptime", duration(ff.Uptime.uptime || 0)])
        const pk = ff.Packages || {}
        if (pk.all !== undefined) { const detail = Object.keys(pk).filter(x => x !== "all" && pk[x]).map(x => pk[x] + " " + x).join(", "); rows.push(["Packages", pk.all + (detail ? "  (" + detail + ")" : "")]) }
        if (shellVersion) rows.push(["Login shell", shellVersion])
        if (ff.Locale) rows.push(["Locale", String(ff.Locale)])
        const ips = ff.LocalIp || []; if (ips.length) rows.push(["Local IP", ips.map(i => (i.ipv4 || i.ipv6 || "") + " (" + i.name + ")").join(", ")])
        if (ff.Loadavg) rows.push(["Load", ff.Loadavg.map(x => x.toFixed(2)).join("  ")])
        return rows
    }
    function hardwareRows(ff) {
        const rows = []
        const b = ff.Board || {}; if (b.name) rows.push(["Board", ((b.vendor || "") + " " + b.name).trim()])
        const bi = ff.BIOS || {}; if (bi.version) rows.push(["BIOS", (bi.vendor || "") + " " + bi.version + " (" + (bi.date || "") + ", " + (bi.type || "") + ")"])
        const c = ff.CPU || {}
        if (c.cpu) { let t = c.cpu; const cores = c.cores || {}, f = c.frequency || {}
            if (cores.physical) t += "  " + cores.physical + "c/" + (cores.logical || "?") + "t"; else if (cores.logical) t += "  " + cores.logical + " threads"
            if (f.max) t += "  up to " + (f.max / 1000).toFixed(2) + " GHz"; rows.push(["CPU", t]) }
        for (const g of (ff.GPU || [])) rows.push([g.type === "Integrated" ? "iGPU" : "GPU", (g.vendor || "") + " " + (g.name || "") + "  ·  " + (g.driver || "")])
        const m = ff.Memory || {}; if (m.total) rows.push(["Memory", gib(m.used) + " / " + gib(m.total)])
        for (const sw of (ff.Swap || [])) rows.push(["Swap", gib(sw.used) + " / " + gib(sw.total) + "  (" + (sw.name || "") + ")"])
        for (const d of (ff.Disk || [])) { if ((d.volumeType || []).indexOf("Subvolume") >= 0) continue; const by = d.bytes || {}
            rows.push(["Disk " + (d.mountpoint || ""), gib(by.used) + " / " + gib(by.total) + (by.total ? "  " + Math.round(by.used / by.total * 100) + "%" : "") + "  " + (d.filesystem || "") + "  " + (d.mountFrom || "")]) }
        for (const disp of (ff.Display || [])) { const o = disp.output || {}, ph = disp.physical || {}
            const inches = (ph.width && ph.height) ? '  ' + Math.round(Math.sqrt(ph.width * ph.width + ph.height * ph.height) / 25.4) + '"' : ""
            rows.push(["Display", (disp.name || "") + "  " + o.width + "x" + o.height + " @ " + Math.round(o.refreshRate || 0) + " Hz" + inches]) }
        for (const s of (ff.Sound || [])) if ((s.type || []).indexOf("active") >= 0) rows.push(["Audio", (s.name || "") + "  (" + (s.platformApi || "") + ")"])
        for (const bt of (ff.Bluetooth || [])) rows.push(["Bluetooth", ((bt.name || "") + " " + (bt.battery || "")).trim()])
        return rows
    }
    function copy() {
        const lines = []
        for (const s of sections) {
            lines.push("# " + s.title)
            for (const [k, v] of s.rows) lines.push(k.padEnd(14) + " " + (v === "@palette" ? swatches.map(sw => sw[0].replace(/ /g, "_") + "=" + sw[1].toString()).join(" ") : v))
            lines.push("")
        }
        Proc.run(["sh", "-c", "printf '%s\\n' \"$QS_TEXT\" | wl-copy"], (code) => { root.status = code === 0 ? "copied to the clipboard" : "wl-copy failed" }, { QS_TEXT: lines.join("\n") })
    }
    Component.onCompleted: collect()

    // Values up to this long sit on the right; longer ones wrap under the label.
    readonly property int shortValue: 40

    Repeater {
        model: root.sections
        Group {
            id: sec
            required property var modelData
            title: sec.modelData.title
            Repeater {
                model: sec.modelData.rows
                SettingRow {
                    id: kv
                    required property var modelData
                    readonly property string key: modelData[0]
                    readonly property string text: modelData[1]
                    readonly property bool isPalette: text === "@palette"
                    readonly property bool wraps: !isPalette && text.length > root.shortValue
                    label: key
                    keywords: isPalette ? "colours colors swatches matugen" : text
                    wide: isPalette || wraps
                    value: (isPalette || wraps) ? "" : text
                    // the long form: dim prose under the label, wrapping across the row
                    Label { visible: kv.wraps; text: kv.text; size: Tokens.fontSizeSmall; dim: true; regular: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    // the palette: the swatch strip with a caption for the hovered one
                    Row {
                        visible: kv.isPalette
                        spacing: 4
                        Repeater {
                            model: kv.isPalette ? root.swatches : []
                            Rectangle {
                                required property var modelData
                                width: 26; height: 18; radius: 5
                                color: modelData[1]
                                border.width: 1; border.color: sma.containsMouse ? Colors.surfaceFg : Tokens.alpha(Colors.outline, 0.35)
                                Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
                                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onEntered: root.hoverCaption = parent.modelData[0] + "  " + parent.modelData[1].toString() }
                            }
                        }
                    }
                    Label { visible: kv.isPalette; text: root.hoverCaption; size: Tokens.fontSizeTiny; dim: true; regular: true; Layout.fillWidth: true }
                }
            }
        }
    }
}
