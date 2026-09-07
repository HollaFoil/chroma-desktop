pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Talking to Hyprland and to the config's state files.
//
// Options go through two channels so a change is immediate *and* survives a
// reload: `hyprctl eval 'hl.config{...}'` applies it live, and it is written
// to ~/.config/hypr/state/settings.json, which lib/settings.lua re-applies on
// every load. Keybinds have no live path: state/keybinds.json is rewritten,
// Hyprland reloads, and lib/actions.lua writes ~/.cache/hypr/binds.json,
// which Binds watches. Per-device input config (Settings > Mouse / Keyboard)
// works like options: `hyprctl eval 'hl.device{...}'` live, persisted under
// "devices" in the same file, re-applied by lib/settings.lua.
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string hyprDir: home + "/.config/hypr"
    // state/ is yours, not the repo's (manifest.txt); a fresh machine may not have it yet
    readonly property string stateDir: hyprDir + "/state"
    readonly property string settingsPath: stateDir + "/settings.json"
    readonly property string keybindsPath: stateDir + "/keybinds.json"
    Component.onCompleted: Proc.run(["mkdir", "-p", stateDir], () => {})

    // ── live ──
    function luaLiteral(v) {
        if (typeof v === "boolean") return v ? "true" : "false"
        if (typeof v === "number") return String(v)
        if (typeof v === "string") return '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
        if (Array.isArray(v)) return "{" + v.map(luaLiteral).join(", ") + "}"
        if (v && typeof v === "object") return "{" + Object.keys(v).map(k => "[" + luaLiteral(k) + "] = " + luaLiteral(v[k])).join(", ") + "}"
        return "nil"
    }
    function nested(name, value) {
        const parts = name.split(":")
        let out = {}; out[parts[parts.length - 1]] = value
        for (let i = parts.length - 2; i >= 0; i--) { const o = {}; o[parts[i]] = out; out = o }
        return out
    }
    // cb(errorText or null)
    function applyLive(name, value, cb) {
        Proc.run(["hyprctl", "eval", "hl.config(" + luaLiteral(nested(name, value)) + ")"], (code, out, err) => {
            const t = (out + err).trim()
            if (cb) cb(t === "ok" ? null : (t || "hyprctl failed"))
        })
    }
    function dispatchLua(code) { Proc.detach(["hyprctl", "dispatch", code]) }
    function reload() { Proc.detach(["hyprctl", "reload"]) }
    function json(args, cb) {
        Proc.run(["hyprctl", "-j"].concat(args), (code, out) => {
            try { cb(JSON.parse(out)) } catch (e) { cb(null) }
        })
    }

    // ── state files ──
    FileView { id: settingsFile; path: root.settingsPath; watchChanges: true; onFileChanged: reload(); onLoaded: root.settings = root.parse(text(), {}) }
    FileView { id: keybindsFile; path: root.keybindsPath; watchChanges: true; onFileChanged: reload(); onLoaded: root.keybinds = root.parse(text(), {}) }
    property var settings: ({})
    property var keybinds: ({})
    function parse(text, fallback) { try { return JSON.parse(text) } catch (e) { return fallback } }

    readonly property var overrides: settings.options ?? ({})
    function isOverridden(name) { return overrides[name] !== undefined }

    // Top-level keys sorted so the file diffs cleanly. (No array replacer: a
    // spec-compliant JSON.stringify would apply it to nested keys as well and
    // drop every option.)
    function writeJson(view, data) {
        const sorted = {}
        for (const k of Object.keys(data).sort()) sorted[k] = data[k]
        view.setText(JSON.stringify(sorted, null, 2) + "\n")
    }
    // Apply live and persist; cb(errorText or null).
    function setOption(name, value, cb) {
        applyLive(name, value, err => {
            if (!err) {
                const data = Object.assign({}, settings)
                data.options = Object.assign({}, data.options ?? {})
                data.options[name] = value
                settings = data
                writeJson(settingsFile, data)
            }
            if (cb) cb(err)
        })
    }
    // Drop the override; a reload puts the conf/*.lua value back.
    function resetOption(name) {
        const data = Object.assign({}, settings)
        data.options = Object.assign({}, data.options ?? {})
        delete data.options[name]
        settings = data
        writeJson(settingsFile, data)
        reload()
    }
    // Several options in one hl.config call (kb_layout with kb_variant, so the
    // lists never disagree for a moment); values: {name: value}. cb(errorText or null).
    function setOptions(values, cb) {
        const tree = {}
        for (const n in values) merge(tree, nested(n, values[n]))
        Proc.run(["hyprctl", "eval", "hl.config(" + luaLiteral(tree) + ")"], (code, out, err) => {
            const t = (out + err).trim()
            const e = t === "ok" ? null : (t || "hyprctl failed")
            if (!e) {
                const data = Object.assign({}, settings)
                data.options = Object.assign({}, data.options ?? {})
                for (const n in values) data.options[n] = values[n]
                settings = data
                writeJson(settingsFile, data)
            }
            if (cb) cb(e)
        })
    }
    function merge(a, b) {
        for (const k in b) {
            if (a[k] && typeof a[k] === "object" && b[k] && typeof b[k] === "object") merge(a[k], b[k])
            else a[k] = b[k]
        }
        return a
    }
    function saveKeybinds(data) {
        keybinds = data
        writeJson(keybindsFile, data)
        reload()
    }
    function keybindsCopy() {
        const d = JSON.parse(JSON.stringify(keybinds))
        d.binds = d.binds ?? {}
        d.custom = d.custom ?? []
        return d
    }

    // ── option schema (settings pages) ──
    // entries: {name: {name, description, default, min, max, map, vtype, current}}
    property var schema: ({})
    property bool schemaLoaded: false
    property bool schemaLoading: false
    signal schemaChanged2()
    function loadSchema(force) {
        if (schemaLoading || (schemaLoaded && !force)) return
        schemaLoading = true
        Proc.run(["hyprctl", "-j", "descriptions"], (code, out) => {
            let entries = []
            try { entries = JSON.parse(out) } catch (e) { entries = [] }
            const names = entries.map(e => e.name)
            Proc.run(["hyprctl", "-j", "--batch", names.map(n => "getoption " + n).join("; ")], (c2, out2) => {
                const live = {}
                const re = /\{[^{}]*\}/g
                let m
                while ((m = re.exec(out2)) !== null) {
                    try {
                        const d = JSON.parse(m[0])
                        const name = d.option; delete d.option; delete d.set
                        const keys = Object.keys(d)
                        if (name && keys.length) live[name] = { vtype: keys[0], current: d[keys[0]] }
                    } catch (e) {}
                }
                const s = {}
                for (const e of entries) {
                    if (live[e.name]) { e.vtype = live[e.name].vtype; e.current = live[e.name].current }
                    s[e.name] = e
                }
                schema = s
                schemaLoaded = true
                schemaLoading = false
                schemaChanged2()
            })
        })
    }
    function refreshCurrent(names, cb) {
        if (!names.length) { if (cb) cb(); return }
        Proc.run(["hyprctl", "-j", "--batch", names.map(n => "getoption " + n).join("; ")], (code, out) => {
            const s = Object.assign({}, schema)
            const re = /\{[^{}]*\}/g
            let m
            while ((m = re.exec(out)) !== null) {
                try {
                    const d = JSON.parse(m[0]); const name = d.option; delete d.option; delete d.set
                    const keys = Object.keys(d)
                    if (name && keys.length && s[name]) { s[name] = Object.assign({}, s[name], { vtype: keys[0], current: d[keys[0]] }) }
                } catch (e) {}
            }
            schema = s
            if (cb) cb()
        })
    }

    // The live value of an option, with Hyprland's "[[EMPTY]]" (an unset
    // string) read as `fallback`; `fallback` also when the schema is not in yet.
    function optionValue(name, fallback) {
        const e = schema[name]
        if (!e) return fallback
        const v = e.current !== undefined ? e.current : e.default
        if (v === undefined || v === null || v === "[[EMPTY]]") return fallback
        return v
    }

    // ── devices (per-device input config) ──
    // `hyprctl -j devices`: { mice: [{name, defaultSpeed, scrollFactor}],
    // keyboards: [{name, layout, variant, options, active_keymap, main, …}],
    // tablets, touch, switches }. Hyprland does not report a device's current
    // settings, so a control shows the override when there is one and the
    // matching global option otherwise.
    property var devices: ({ mice: [], keyboards: [], tablets: [], touch: [], switches: [] })
    function refreshDevices() {
        json(["devices"], d => {
            if (!d) return
            devices = { mice: d.mice ?? [], keyboards: d.keyboards ?? [], tablets: d.tablets ?? [], touch: d.touch ?? [], switches: d.switches ?? [] }
        })
    }
    // "corsair-corsair-gaming-k63-keyboard-1" -> "Corsair Gaming K63 Keyboard"
    readonly property var acronyms: ({ hp: "HP", usb: "USB", hid: "HID", bt: "BT", ble: "BLE", ii: "II", iii: "III", iv: "IV", mx: "MX", tkl: "TKL", rgb: "RGB", wmi: "WMI", pc: "PC", inc: "Inc." })
    function prettyDevice(name) {
        const words = String(name).replace(/-\d+$/, "").split("-").filter(w => w.length > 0)
        const out = []
        for (const w of words) {
            if (out.length && out[out.length - 1].toLowerCase() === w.toLowerCase()) continue
            out.push(w)
        }
        return out.map(w => acronyms[w.toLowerCase()] ?? (w.charAt(0).toUpperCase() + w.slice(1))).join(" ")
    }

    readonly property var deviceOverrides: settings.devices ?? ({})
    function hasDeviceOverride(name, field) {
        const d = deviceOverrides[name]
        return d !== undefined && d !== null && d[field] !== undefined
    }
    function deviceValue(name, field, fallback) {
        return hasDeviceOverride(name, field) ? deviceOverrides[name][field] : fallback
    }
    // Apply live and persist under devices[name][field]; cb(errorText or null).
    function setDevice(name, field, value, cb) {
        const dev = { name: name }
        dev[field] = value
        Proc.run(["hyprctl", "eval", "hl.device(" + luaLiteral(dev) + ")"], (code, out, err) => {
            const t = (out + err).trim()
            const e = t === "ok" ? null : (t || "hyprctl failed")
            if (!e) {
                const data = Object.assign({}, settings)
                data.devices = Object.assign({}, data.devices ?? {})
                data.devices[name] = Object.assign({}, data.devices[name] ?? {})
                data.devices[name][field] = value
                settings = data
                writeJson(settingsFile, data)
            }
            if (cb) cb(e)
        })
    }
    // Drop one override (and the device when nothing is left); a reload puts
    // the config's value back.
    function resetDevice(name, field) {
        const data = Object.assign({}, settings)
        data.devices = Object.assign({}, data.devices ?? {})
        if (data.devices[name]) {
            data.devices[name] = Object.assign({}, data.devices[name])
            delete data.devices[name][field]
            if (Object.keys(data.devices[name]).length === 0) delete data.devices[name]
        }
        if (Object.keys(data.devices).length === 0) delete data.devices
        settings = data
        writeJson(settingsFile, data)
        reload()
    }
}
