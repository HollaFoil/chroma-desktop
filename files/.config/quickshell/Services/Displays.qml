pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Monitors: what is connected (hyprctl monitors all), the rule we want for
// each one, and the two files those rules live in.
//
//   ~/.config/hypr/monitors.lua         one hl.monitor{} per output, read at every reload
//   ~/.config/hypr/state/monitors.json  { primary, ws_home, rules }: which monitor owns
//                                       workspaces 1-5 (the bar and lib/workspaces.lua
//                                       read ws_home) and the rules the lua was made from
//
// A change is applied live with `hyprctl eval 'hl.monitor{...}'`. Safe ones
// (position, VRR, colour) are committed at once; ones that can leave a screen
// black (mode, scale, rotation, disabling) start a countdown and are reverted
// unless keep() is called. commit() rewrites both files and, when the
// workspace map changed, reloads Hyprland so lib/workspaces.lua sees it.
// gen-monitors and nwg-displays write the same monitors.lua shape.
Singleton {
    id: root
    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property string luaPath: hyprDir + "/monitors.lua"
    readonly property string statePath: hyprDir + "/state/monitors.json"
    readonly property int perMon: 5
    readonly property int bank: 10
    readonly property int revertSeconds: 15

    property var monitors: []                 // hyprctl -j monitors all
    property var state: ({})                  // parsed monitors.json
    readonly property var wsHome: state.ws_home ?? ({})
    readonly property var rules: state.rules ?? ({})
    readonly property string primary: state.primary ?? (wsHome["1"] ?? biggest())
    property var snapshot: null               // rules before the pending risky change
    property int countdown: 0
    property string status: ""
    property bool statusError: false

    readonly property var enabled: monitors.filter(m => !m.disabled)
    readonly property var names: monitors.map(m => m.name)
    function byName(n) { return monitors.find(m => m.name === n) ?? null }
    function biggest() {
        let best = null
        for (const m of enabled) if (!best || m.width * m.height > best.width * best.height || (m.width * m.height === best.width * best.height && m.x < best.x)) best = m
        return best ? best.name : ""
    }

    // ── reading ──
    function refresh() { Hypr.json(["monitors", "all"], m => { if (m) monitors = m }) }
    Timer { id: refreshSoon; interval: 400; onTriggered: root.refresh() }
    Connections { target: Hyprland; function onRawEvent(ev) { if (String(ev.name).indexOf("monitor") === 0 || ev.name === "configreloaded") refreshSoon.restart() } }
    Component.onCompleted: refresh()
    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.state = JSON.parse(text()) || {} } catch (e) { root.state = {} } }
    }

    // ── modes ──
    function fmtHz(v) { return (Math.round(v * 100) / 100).toFixed(2).replace(/\.?0+$/, "") }
    function parseMode(s) { const m = /^(\d+)x(\d+)@([\d.]+)/.exec(String(s)); return m ? { w: +m[1], h: +m[2], hz: +m[3] } : null }
    function modeString(w, h, hz) { return w + "x" + h + "@" + fmtHz(hz) }
    function modesOf(m) { return (m && m.availableModes ? m.availableModes : []).map(parseMode).filter(x => x) }
    function sameHz(a, b) { return Math.abs(a - b) < 0.02 }

    // The rule for one output: what monitors.json says, over what the compositor reports now.
    function seed(m) {
        if (!m) return { mode: "preferred", position: "auto", scale: 1, transform: 0, vrr: 0, bitdepth: 8, cm: "srgb", sdrbrightness: 1, sdrsaturation: 1, mirror: "", disabled: false }
        return {
            mode: (m.width && m.height) ? modeString(m.width, m.height, m.refreshRate) : "preferred",
            position: m.x + "x" + m.y,
            scale: m.scale || 1,
            transform: m.transform || 0,
            vrr: m.vrr ? 1 : 0,
            bitdepth: /2101010/.test(m.currentFormat || "") ? 10 : 8,
            cm: m.colorManagementPreset || "srgb",
            sdrbrightness: m.sdrBrightness ?? 1,
            sdrsaturation: m.sdrSaturation ?? 1,
            mirror: (m.mirrorOf && m.mirrorOf !== "none") ? m.mirrorOf : "",
            disabled: !!m.disabled
        }
    }
    function ruleOf(name) { return Object.assign(seed(byName(name)), rules[name] ?? {}) }
    function allRules() { const out = {}; for (const m of monitors) out[m.name] = ruleOf(m.name); return out }

    // Logical size (after scale and rotation), what positions are measured in.
    function logical(name) {
        const m = byName(name), r = ruleOf(name)
        const md = parseMode(r.mode) || { w: m ? m.width : 0, h: m ? m.height : 0 }
        const s = Number(r.scale) || 1
        let w = Math.round(md.w / s), h = Math.round(md.h / s)
        if (r.transform % 2 === 1) { const t = w; w = h; h = t }
        const p = /^(-?\d+)x(-?\d+)/.exec(r.position)
        return { x: p ? +p[1] : (m ? m.x : 0), y: p ? +p[2] : (m ? m.y : 0), w, h }
    }

    // ── writing ──
    function luaLiteral(v) { return typeof v === "string" ? '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"' : String(v) }
    // The rule as Lua. `full` names every field (what a live apply needs:
    // Hyprland merges a new rule over the old one, so an omitted field keeps
    // its previous value); the file gets the compact form, since a reload
    // starts from nothing.
    function luaOf(name, r, full) {
        if (r.disabled) return 'hl.monitor({ output = ' + luaLiteral(name) + ', disabled = true })'
        const f = ['output = ' + luaLiteral(name), 'mode = ' + luaLiteral(r.mode), 'position = ' + luaLiteral(r.position), 'scale = ' + r.scale]
        if (full || r.transform) f.push('transform = ' + (r.transform || 0))
        f.push('vrr = ' + r.vrr)
        if (full || r.bitdepth === 10) f.push('bitdepth = ' + (r.bitdepth === 10 ? 10 : 8))
        if (full || (r.cm && r.cm !== "srgb")) f.push('cm = ' + luaLiteral(r.cm || "srgb"))
        if (full || Number(r.sdrbrightness) !== 1) f.push('sdrbrightness = ' + (Number(r.sdrbrightness) || 1))
        if (full || Number(r.sdrsaturation) !== 1) f.push('sdrsaturation = ' + (Number(r.sdrsaturation) || 1))
        if (full || r.mirror) f.push('mirror = ' + luaLiteral(r.mirror || ""))
        if (full) f.push('disabled = false')
        return full ? 'hl.monitor({ ' + f.join(', ') + ' })' : 'hl.monitor({\n    ' + f.join(',\n    ') + '\n})'
    }
    // hyprctl eval prefixes "return ", so several statements go through a function
    function batch(stmts) { return "(function() " + stmts.join(" ") + " end)()" }
    function luaFile(rs) {
        const names = Object.keys(rs).sort((a, b) => logical(a).x - logical(b).x)
        const now = new Date()
        const pad = n => String(n).padStart(2, "0")
        const stamp = now.getFullYear() + "-" + pad(now.getMonth() + 1) + "-" + pad(now.getDate()) + " at " + pad(now.getHours()) + ":" + pad(now.getMinutes()) + ":" + pad(now.getSeconds())
        return "-- Generated by Settings > Displays on " + stamp + ". Do not edit manually.\n" +
               "-- (gen-monitors and nwg-displays write this file too, in the same shape.)\n\n" +
               names.map(n => luaOf(n, rs[n])).join("\n") + "\n"
    }
    // Workspace banks: the primary takes 1-5, the rest left to right 11-15, 21-25 (gen-monitors' rule).
    function deal(rs, prim) {
        const on = Object.keys(rs).filter(n => !rs[n].disabled && byName(n)).sort((a, b) => logical(a).x - logical(b).x)
        if (!on.length) return {}
        const order = on.indexOf(prim) >= 0 ? [prim].concat(on.filter(n => n !== prim)) : on
        const map = {}
        order.forEach((n, slot) => { for (let i = 1; i <= perMon; i++) map[String(slot * bank + i)] = n })
        return map
    }
    function writeThrough(path, text, cb) {
        Proc.run(["sh", "-c", 'printf %s "$QS_TEXT" > "$(readlink -f "$1" 2>/dev/null || printf %s "$1")"', "sh", path], cb, { QS_TEXT: text })
    }
    // Persist the current rules; `prim` overrides the primary. Reloads Hyprland when the workspace map moved.
    function commit(prim) {
        const rs = allRules()
        const p = prim ?? primary
        const map = deal(rs, p)
        const changed = JSON.stringify(map) !== JSON.stringify(wsHome)
        const data = {
            _comment: "Written by Settings > Displays (gen-monitors writes ws_home too): primary = owner of workspaces 1-5, ws_home = workspace -> monitor, rules = what monitors.lua was generated from.",
            primary: p,
            ws_home: map,
            rules: rs
        }
        state = data
        stateFile.setText(JSON.stringify(data, null, 2) + "\n")
        writeThrough(luaPath, luaFile(rs), (code, out, err) => {
            if (code !== 0) { status = "could not write monitors.lua: " + (err || out).trim(); statusError = true; return }
            status = changed ? "saved · workspaces re-dealt" : "saved"; statusError = false
            if (changed) Hypr.reload()
            stamp.restart()
        })
    }
    Timer { id: stamp; interval: 4000; onTriggered: root.status = "" }
    function setPrimary(name) { commit(name) }

    // ── applying ──
    // Merge `patch` into the rule for `name` and apply it live. Risky changes
    // start the revert countdown; keep() commits them, revert() undoes them.
    function apply(name, patch, risky, cb) {
        const before = allRules()
        const r = Object.assign(ruleOf(name), patch)
        const rs = Object.assign({}, rules); rs[name] = r
        state = Object.assign({}, state, { rules: rs })
        Proc.run(["hyprctl", "eval", luaOf(name, r, true)], (code, out, err) => {
            const t = (out + err).trim()
            if (t !== "ok") {
                status = t || "hyprctl failed"; statusError = true
                state = Object.assign({}, state, { rules: before })
                if (cb) cb(false)
                return
            }
            statusError = false
            refreshSoon.restart()
            if (risky) { if (!snapshot) snapshot = before; countdown = revertSeconds; tick.restart() }
            else commit()
            if (cb) cb(true)
        })
    }
    // Move several outputs at once (a drag that shifted the layout): [{ name, position }].
    function applyPositions(list) {
        let pending = list.length
        if (!pending) return
        const rs = Object.assign({}, rules)
        for (const it of list) rs[it.name] = Object.assign(ruleOf(it.name), { position: it.position })
        state = Object.assign({}, state, { rules: rs })
        Proc.run(["hyprctl", "eval", batch(Object.keys(rs).filter(n => !rs[n].disabled && byName(n)).map(n => luaOf(n, rs[n], true)))], (c, out, err) => {
            const t = (out + err).trim()
            if (t !== "ok") { status = t || "hyprctl failed"; statusError = true; refresh(); return }
            refreshSoon.restart()
            commit()
        })
    }
    Timer {
        id: tick
        interval: 1000; repeat: true
        running: root.countdown > 0
        onTriggered: { root.countdown--; if (root.countdown <= 0) root.revert() }
    }
    function keep() { snapshot = null; countdown = 0; commit() }
    function revert() {
        const snap = snapshot
        snapshot = null; countdown = 0
        if (!snap) return
        state = Object.assign({}, state, { rules: snap })
        Proc.run(["hyprctl", "eval", batch(Object.keys(snap).filter(n => byName(n)).map(n => luaOf(n, snap[n], true)))], () => { refreshSoon.restart(); status = "reverted"; statusError = false; stamp.restart() })
    }
}
