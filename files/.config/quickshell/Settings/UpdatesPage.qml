import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Updates: what is waiting, when the last upgrade ran, and the two clean-ups.
//   Available     repo (checkupdates), AUR (yay -Qua), Flatpak, firmware
//                 (fwupdmgr); each checked on its own, so a slow one does not
//                 hold the others back. Names of the first dozen as the hint.
//   History       last full upgrade from pacman.log, kernel, package counts
//   Maintenance   package cache size, clean cache, remove orphans (advanced)
// Nothing here upgrades or removes anything itself: "Update now", "Clean
// cache" and "Remove orphans" open a terminal running yay, where pacman can
// ask its questions.
PageBody {
    id: root
    title: "Updates"
    subtitle: "Packages and firmware"
    headerItems: [
        Pill { text: "󰑐  Refresh"; small: true; enabled: !root.anyBusy; onClicked: root.refresh() },
        Pill { text: "󰚰  Update now"; small: true; on: root.total > 0; onClicked: root.updateNow() }
    ]

    // one record per source: busy while its command runs, then names or an error
    property var sources: ({
        repo:    { busy: false, names: [], error: "" },
        aur:     { busy: false, names: [], error: "" },
        flatpak: { busy: false, names: [], error: "" },
        fw:      { busy: false, names: [], error: "" }
    })
    property bool hasFlatpak: true
    function setSource(key, rec) { const s = Object.assign({}, sources); s[key] = rec; sources = s }
    readonly property bool anyBusy: sources.repo.busy || sources.aur.busy || sources.flatpak.busy || sources.fw.busy
    readonly property int total: sources.repo.names.length + sources.aur.names.length + sources.flatpak.names.length + sources.fw.names.length
    readonly property bool anyError: !!(sources.repo.error || sources.aur.error || sources.flatpak.error || sources.fw.error)
    status: anyBusy ? "checking…" : total > 0 ? total + (total === 1 ? " update available" : " updates available") : anyError ? "" : "everything is up to date"

    function countText(rec) { return rec.busy ? "checking…" : rec.error ? "?" : rec.names.length === 0 ? "up to date" : String(rec.names.length) }
    function namesText(rec) {
        if (rec.busy) return ""
        if (rec.error) return rec.error
        const shown = rec.names.slice(0, 12)
        return shown.join(", ") + (rec.names.length > shown.length ? " and " + (rec.names.length - shown.length) + " more" : "")
    }
    function firstLine(t) { return (t || "").trim().split("\n")[0] || "" }

    function checkRepo() {
        setSource("repo", { busy: true, names: [], error: "" })
        Proc.run(["checkupdates"], (code, out, err) => {
            // 0: a list, 2: nothing to do, anything else: could not check
            if (code === 2) { setSource("repo", { busy: false, names: [], error: "" }); return }
            if (code !== 0) { setSource("repo", { busy: false, names: [], error: firstLine(err) || "checkupdates failed" }); return }
            setSource("repo", { busy: false, names: out.split("\n").filter(l => l.indexOf(" -> ") > 0).map(l => l.split(" ")[0]), error: "" })
        })
    }
    function checkAur() {
        setSource("aur", { busy: true, names: [], error: "" })
        Proc.run(["yay", "-Qua"], (code, out, err) => {
            const names = out.split("\n").filter(l => l.indexOf(" -> ") > 0).map(l => l.split(" ")[0])
            // yay exits non-zero when there is nothing, too; only an unreadable stderr with no list is an error
            const error = (code !== 0 && names.length === 0 && /error|fail|unable/i.test(err)) ? firstLine(err) : ""
            setSource("aur", { busy: false, names, error })
        })
    }
    function checkFlatpak() {
        setSource("flatpak", { busy: true, names: [], error: "" })
        Proc.sh('command -v flatpak >/dev/null || { echo "@@none"; exit 0; }; flatpak remote-ls --updates --columns=application', (code, out, err) => {
            if (out.indexOf("@@none") === 0) { hasFlatpak = false; setSource("flatpak", { busy: false, names: [], error: "" }); return }
            hasFlatpak = true
            if (code !== 0) { setSource("flatpak", { busy: false, names: [], error: firstLine(err) || "flatpak failed" }); return }
            setSource("flatpak", { busy: false, names: out.split("\n").map(l => l.trim()).filter(l => l.length), error: "" })
        })
    }
    function checkFirmware() {
        setSource("fw", { busy: true, names: [], error: "" })
        Proc.run(["fwupdmgr", "get-updates", "--json"], (code, out, err) => {
            let data = null
            try { data = JSON.parse(out) } catch (e) { data = null }
            if (data && Array.isArray(data.Devices)) {
                const names = data.Devices.map(d => { const rel = (d.Releases || [])[0]; return (d.Name || d.DeviceId || "device") + (rel && rel.Version ? " → " + rel.Version : "") })
                setSource("fw", { busy: false, names, error: "" })
                return
            }
            const msg = firstLine(err) || firstLine(out)
            // "no updates" is not an error, just an empty list
            if (code === 0 || /no updat|no upgrad/i.test(msg)) { setSource("fw", { busy: false, names: [], error: "" }); return }
            setSource("fw", { busy: false, names: [], error: msg || "fwupdmgr failed (offline?)" })
        })
    }

    // history
    property string lastUpgrade: ""
    property string kernel: ""
    property string installedCount: ""
    property int orphans: 0
    property string cacheSize: ""
    function readHistory() {
        Proc.sh('grep "starting full system upgrade" /var/log/pacman.log 2>/dev/null | tail -1; echo @@; uname -r; echo @@; pacman -Q | wc -l; echo @@; pacman -Qdtq 2>/dev/null | wc -l; echo @@; du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1', (code, out) => {
            const p = out.split("@@").map(s => s.trim())
            const m = /^\[(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/.exec(p[0] || "")
            lastUpgrade = m ? m[1] + " " + m[2] : (p[0] ? p[0] : "never (nothing in pacman.log)")
            kernel = p[1] || ""
            installedCount = p[2] || ""
            orphans = parseInt(p[3]) || 0
            cacheSize = p[4] || "?"
        })
    }

    function refresh() { checkRepo(); checkAur(); checkFlatpak(); checkFirmware(); readHistory() }
    function inTerminal(title, script) {
        Overlays.settingsToggle()
        Proc.detach(["kitty", "--title", title, "sh", "-c", script + "; echo; read -p 'done, press Enter'"])
    }
    function updateNow() {
        let script = "yay -Syu"
        if (hasFlatpak) script += "; flatpak update"
        if (sources.fw.names.length > 0) script += "; fwupdmgr update"
        inTerminal("Updates", script)
    }
    Component.onCompleted: refresh()

    Group {
        title: "Available"
        SettingRow {
            label: "Repository packages"
            hint: root.namesText(root.sources.repo)
            keywords: "pacman checkupdates repo " + root.sources.repo.names.join(" ")
            value: root.countText(root.sources.repo)
        }
        SettingRow {
            label: "AUR packages"
            hint: root.namesText(root.sources.aur)
            keywords: "yay aur " + root.sources.aur.names.join(" ")
            value: root.countText(root.sources.aur)
        }
        SettingRow {
            visible: root.hasFlatpak && hit
            label: "Flatpak"
            hint: root.namesText(root.sources.flatpak)
            keywords: "flatpak flathub " + root.sources.flatpak.names.join(" ")
            value: root.countText(root.sources.flatpak)
        }
        SettingRow {
            label: "Firmware"
            hint: root.namesText(root.sources.fw)
            keywords: "fwupd fwupdmgr firmware bios lvfs " + root.sources.fw.names.join(" ")
            value: root.countText(root.sources.fw)
        }
    }

    Group {
        title: "History"
        SettingRow { label: "Last full upgrade"; hint: "From /var/log/pacman.log"; keywords: "pacman log upgrade date"; value: root.lastUpgrade }
        SettingRow { label: "Kernel"; hint: "The one running now"; keywords: "uname linux kernel version"; value: root.kernel }
        SettingRow { label: "Packages installed"; keywords: "pacman -Q count"; value: root.installedCount }
        SettingRow { label: "Orphans"; hint: "Installed as dependencies, needed by nothing any more"; keywords: "pacman -Qdtq orphan unused dependencies"; value: String(root.orphans) }
    }

    Group {
        title: "Maintenance"
        advanced: true
        SettingRow { label: "Package cache"; hint: "/var/cache/pacman/pkg"; keywords: "cache size disk space pacman pkg"; value: root.cacheSize }
        SettingRow {
            label: "Clean cache"
            hint: "yay -Sc in a terminal: drops cached packages that are no longer installed"
            keywords: "clean cache yay -Sc paccache"
            clickable: true
            onClicked: root.inTerminal("Clean cache", "yay -Sc")
        }
        SettingRow {
            label: "Remove orphans"
            hint: root.orphans > 0 ? "yay -Rns of the " + root.orphans + " packages nothing depends on" : "Nothing to remove"
            keywords: "remove orphans yay -Rns"
            clickable: true
            enabled: root.orphans > 0
            onClicked: if (root.orphans > 0) root.inTerminal("Remove orphans", "yay -Rns $(pacman -Qdtq)")
        }
    }
}
