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
// which Binds watches.
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string hyprDir: home + "/.config/hypr"
    readonly property string settingsPath: hyprDir + "/state/settings.json"
    readonly property string keybindsPath: hyprDir + "/state/keybinds.json"

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

    function writeJson(view, data) {
        view.setText(JSON.stringify(data, Object.keys(data).sort(), 2) + "\n")
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
}
