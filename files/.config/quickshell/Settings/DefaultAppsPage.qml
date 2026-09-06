import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Default apps: which desktop entry xdg-open hands each kind of thing to.
//     Defaults    one Picker per role (browser, mail, files, text, images…);
//                 the candidates are the apps mimeinfo.cache lists for the
//                 role's MIME types, the value is `xdg-mime query default`
//     Keybinds    the terminal and file manager SUPER+Q / SUPER+E launch
//                 (read from the top of conf/actions.lua, changed there)
//     Advanced    the same picker for any MIME type you type, and the file
// Setting a role runs `xdg-mime default <app> <every mime of the role>`; the
// browser also goes through `xdg-settings set default-web-browser`.
PageBody {
    id: root
    title: "Default apps"
    subtitle: "Which app opens what"
    readonly property string home: Quickshell.env("HOME")
    readonly property var roles: [
        { id: "browser", label: "Web browser", hint: "http and https links", keywords: "firefox chromium internet links html",
          mimes: ["x-scheme-handler/http", "x-scheme-handler/https"] },
        { id: "mail",    label: "Mail",        hint: "mailto: links",           keywords: "email thunderbird",
          mimes: ["x-scheme-handler/mailto"] },
        { id: "files",   label: "Files",       hint: "Folders",                 keywords: "file manager directory folder nemo",
          mimes: ["inode/directory"] },
        { id: "text",    label: "Text",        hint: "Plain text files",        keywords: "editor txt",
          mimes: ["text/plain"] },
        { id: "images",  label: "Images",      hint: "JPEG, PNG and WebP",      keywords: "picture photo viewer jpg png webp",
          mimes: ["image/jpeg", "image/png", "image/webp"] },
        { id: "video",   label: "Video",       hint: "MP4 and Matroska",        keywords: "movie player mp4 mkv mpv",
          mimes: ["video/mp4", "video/x-matroska"] },
        { id: "music",   label: "Music",       hint: "MP3 and FLAC",            keywords: "audio player song mp3 flac",
          mimes: ["audio/mpeg", "audio/flac"] },
        { id: "pdf",     label: "PDF",         hint: "Documents",               keywords: "reader document viewer",
          mimes: ["application/pdf"] }
    ]
    property var cache: ({})        // mime -> [desktop files], from mimeinfo.cache
    property var defaults: ({})     // mime -> desktop file, from xdg-mime query default
    property int rev: 0             // bumped when either changes, so bindings re-run
    property string terminalCmd: ""
    property string fileManagerCmd: ""
    property string customMime: ""
    property string customDefault: ""

    // ── reading ──
    function refresh() {
        const mimes = []
        for (const r of roles) for (const m of r.mimes) mimes.push(m)
        Proc.sh("cat /usr/share/applications/mimeinfo.cache \"$HOME/.local/share/applications/mimeinfo.cache\" 2>/dev/null; echo @@; "
                + "for m in " + mimes.join(" ") + "; do printf '%s=%s\\n' \"$m\" \"$(xdg-mime query default \"$m\" 2>/dev/null)\"; done; echo @@; "
                + "grep -E '^local (terminal|fileManager) *=' \"$HOME/.config/hypr/conf/actions.lua\"", (code, out) => {
            const parts = out.split("@@")
            const c = {}
            for (const line of (parts[0] || "").split("\n")) {
                const eq = line.indexOf("=")
                if (eq <= 0 || line.startsWith("[")) continue
                const mime = line.slice(0, eq), apps = line.slice(eq + 1).split(";").filter(a => a.length)
                c[mime] = (c[mime] || []).concat(apps.filter(a => (c[mime] || []).indexOf(a) < 0))
            }
            const d = {}
            for (const line of (parts[1] || "").split("\n")) {
                const eq = line.indexOf("=")
                if (eq > 0) d[line.slice(0, eq).trim()] = line.slice(eq + 1).trim()
            }
            for (const line of (parts[2] || "").split("\n")) {
                const m = /^local\s+(terminal|fileManager)\s*=\s*"([^"]*)"/.exec(line.trim())
                if (m && m[1] === "terminal") root.terminalCmd = m[2]
                if (m && m[1] === "fileManager") root.fileManagerCmd = m[2]
            }
            root.cache = c; root.defaults = d; root.rev++
            if (root.customMime) root.queryCustom()
        })
    }
    function queryCustom() {
        const m = customMime
        Proc.run(["xdg-mime", "query", "default", m], (code, out) => { if (m === root.customMime) root.customDefault = out.trim() })
    }
    Component.onCompleted: refresh()

    // ── desktop entries ──
    function entryFor(file) {
        const id = file.replace(/\.desktop$/, "")
        const list = DesktopEntries.applications.values
        return list.find(e => e.id === id) ?? null
    }
    function nameOf(file) { const e = entryFor(file); return e && e.name ? e.name : file.replace(/\.desktop$/, "") }
    function iconOf(file) { const e = entryFor(file); return (e && e.icon) ? Quickshell.iconPath(e.icon, "application-x-executable") : "" }
    // every app mimeinfo.cache lists for any of the mimes, plus whatever is the default now
    function candidates(mimes) {
        rev
        const files = []
        for (const m of mimes) {
            for (const a of (cache[m] || [])) if (files.indexOf(a) < 0) files.push(a)
            const d = defaults[m]
            if (d && files.indexOf(d) < 0) files.push(d)
        }
        return files.map(f => ({ text: nameOf(f), value: f, hint: f })).sort((a, b) => a.text.localeCompare(b.text))
    }
    function currentOf(mimes) { rev; return defaults[mimes[0]] || undefined }
    function mixed(mimes) { rev; const first = defaults[mimes[0]]; return mimes.some(m => defaults[m] !== first) }

    // ── writing ──
    function setDefault(app, mimes, isBrowser, label) {
        Proc.run(["xdg-mime", "default", app].concat(mimes), (code, out, err) => {
            if (code !== 0) { root.status = "xdg-mime failed: " + (err || out).trim(); root.statusError = true; return }
            const done = () => { root.status = label + " opens with " + nameOf(app); root.statusError = false; refresh() }
            if (isBrowser) Proc.run(["xdg-settings", "set", "default-web-browser", app], (c2, o2, e2) => {
                if (c2 !== 0) { root.status = "set for links, but xdg-settings failed: " + (e2 || o2).trim(); root.statusError = true; refresh() } else done()
            })
            else done()
        })
    }
    function openMimeapps() {
        Overlays.settingsToggle()
        Proc.detach(["sh", "-c",
            "f=\"$0\"; ed=\"${VISUAL:-${EDITOR:-}}\"; "
            + "if [ -z \"$ed\" ] && [ -n \"$SHELL\" ]; then ed=\"$(\"$SHELL\" -lc 'echo \"$VISUAL\"; echo \"$EDITOR\"' 2>/dev/null | grep -m1 .)\"; fi; "
            + "case \"${ed##*/}\" in codium*|code*|kate|kwrite|gedit|gnome-text-editor|mousepad|subl*|zed*|zeditor) exec $ed \"$f\";; esac; "
            + "[ -z \"$ed\" ] && { command -v nano >/dev/null 2>&1 && ed=nano || ed=vi; }; "
            + "exec kitty --title edit sh -c \"exec $ed \\\"\\$0\\\"\" \"$f\"",
            home + "/.config/mimeapps.list"])
    }

    headerItems: [ Pill { text: "󰑓  Re-read"; small: true; onClicked: root.refresh() } ]

    Group {
        title: "Defaults"
        hint: "What xdg-open and “open with” use. The list shows every installed app that registers the type."
        Repeater {
            model: root.roles
            SettingRow {
                id: row
                required property var modelData
                readonly property var items: root.candidates(modelData.mimes)
                readonly property var cur: root.currentOf(modelData.mimes)
                label: modelData.label
                hint: modelData.hint + (root.mixed(modelData.mimes) ? "  ·  the types of this role currently differ; picking an app sets all of them" : "")
                keywords: modelData.keywords + " " + modelData.mimes.join(" ")
                Image {
                    visible: source.toString().length > 0
                    source: row.cur ? root.iconOf(row.cur) : ""
                    sourceSize.width: 18; sourceSize.height: 18
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                }
                Picker {
                    model: row.items
                    current: row.cur
                    placeholder: row.items.length ? "Choose…" : "no app registers this"
                    enabled: row.items.length > 0
                    minWidth: 200
                    onPicked: v => root.setDefault(v, row.modelData.mimes, row.modelData.id === "browser", row.modelData.label)
                }
            }
        }
    }

    Group {
        title: "Keybinds"
        hint: "Set at the top of conf/actions.lua; the keys themselves are changed on the Keybinds page"
        SettingRow {
            label: "Terminal"
            hint: (Binds.keysOf("app.terminal").length ? Binds.keysOf("app.terminal").map(Binds.prettyCombo).join(", ") + "  ·  " : "") + "local terminal = … in conf/actions.lua"
            keywords: "kitty console shell"
            value: root.terminalCmd || "…"
            clickable: true
            onClicked: Overlays.openSettings("keybinds")
        }
        SettingRow {
            label: "File manager"
            hint: (Binds.keysOf("app.files").length ? Binds.keysOf("app.files").map(Binds.prettyCombo).join(", ") + "  ·  " : "") + "local fileManager = … in conf/actions.lua"
            keywords: "nemo folders"
            value: root.fileManagerCmd || "…"
            clickable: true
            onClicked: Overlays.openSettings("keybinds")
        }
    }

    Group {
        title: "Advanced"
        advanced: true
        hint: "Any MIME type, and the file all of this lives in"
        SettingRow {
            label: "MIME type"
            hint: "Type one (image/svg+xml, x-scheme-handler/magnet…) and pick its app below"
            keywords: "custom scheme handler"
            Entry {
                Layout.preferredWidth: 240
                placeholder: "type/subtype"
                onEditingFinished: { root.customMime = text.trim(); root.customDefault = ""; if (root.customMime) root.queryCustom() }
            }
        }
        SettingRow {
            id: customRow
            readonly property var items: root.customMime ? root.candidates([root.customMime]).concat(
                (root.customDefault && !root.candidates([root.customMime]).some(i => i.value === root.customDefault))
                    ? [{ text: root.nameOf(root.customDefault), value: root.customDefault, hint: root.customDefault }] : []) : []
            label: root.customMime ? "Opens " + root.customMime + " with" : "Opens with"
            hint: !root.customMime ? "Enter a MIME type above" : items.length ? "" : "No installed app registers this type"
            keywords: "handler app for type"
            enabled: root.customMime.length > 0
            Picker {
                model: customRow.items
                current: root.customDefault || undefined
                placeholder: root.customMime ? (customRow.items.length ? "none set" : "nothing registers it") : "—"
                enabled: customRow.items.length > 0
                minWidth: 200
                onPicked: v => root.setDefault(v, [root.customMime], false, root.customMime)
            }
        }
        SettingRow {
            label: "Open mimeapps.list"
            hint: "~/.config/mimeapps.list, the file xdg-mime writes; edit it by hand for anything not on this page"
            keywords: "edit file associations"
            clickable: true
            onClicked: root.openMimeapps()
        }
    }
}
