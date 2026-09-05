pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Pipewire, plus per-app output routing.
//
// Every playing stream can be sent to a device other than the default sink
// for one of three lifetimes: "stream" (this one stream, nothing remembered),
// "session" (a rule for the app in $XDG_RUNTIME_DIR, gone at logout) or
// "always" (a rule in ~/.local/state/quickshell/audio-routes.json). Rules are
// applied here as streams appear and when a device shows up, so the shell is
// the daemon barpop-watch used to be. Moves go through pw-metadata
// (target.object on the stream node), which is what wpctl does too.
Singleton {
    id: root

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !/\.monitor$/.test(n.name))
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    readonly property PwNode defaultSource: Pipewire.defaultAudioSource

    PwObjectTracker { objects: root.sinks.concat(root.sources, root.streams) }

    // ── volume helpers (0..1) ──
    function pct(node) { return node && node.audio ? Math.round(node.audio.volume * 100) : 0 }
    function setVolume(node, v) { if (node && node.audio) node.audio.volume = Math.max(0, Math.min(1.5, v)) }
    function toggleMute(node) { if (node && node.audio) node.audio.muted = !node.audio.muted }
    function setDefaultSink(node) { Pipewire.preferredDefaultAudioSink = node }
    function setDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node }

    readonly property var speakerIcons: ["󰕿", "󰖀", "󰕾"]
    function speakerIcon(p, muted) { return (muted || p === 0) ? "󰝟" : speakerIcons[Math.min(2, Math.floor(p * 3 / 101))] }
    function micIcon(muted) { return muted ? "󰍭" : "󰍬" }

    // 'GP102 HDMI Audio Controller Digital Stereo (HDMI) [LG QHD]' -> 'LG QHD'
    function shortName(node) {
        let d = node ? (node.description || node.nickname || node.name) : "—"
        const m = d.match(/\[([^\]]+)\]$/)
        if (m) return m[1]
        for (const s of [" Analog Stereo", " Digital Stereo", " Stereo", " Mono"]) d = d.replace(s, "")
        return d.trim()
    }

    // ── app identity ──
    readonly property var appOverrides: ({
        "spotify": { icon: "spotify-launcher", label: "Spotify" },
        "vesktop": { icon: "discord", label: "Discord" },
        "webcord": { icon: "discord", label: "Discord" },
        "armcord": { icon: "discord", label: "Discord" }
    })
    function props(node) { return (node && node.properties) ? node.properties : {} }
    function appKey(node) {
        const p = props(node)
        return p["application.name"] || p["application.process.binary"] || node.name || ""
    }
    function appLabel(node) {
        const p = props(node)
        for (const k of [p["application.name"], p["application.process.binary"], node.name])
            if (k && appOverrides[k.toLowerCase()]) return appOverrides[k.toLowerCase()].label
        return p["application.name"] || p["media.name"] || node.name || ("stream " + node.id)
    }
    function appIcon(node) {
        const p = props(node)
        for (const k of [p["application.name"], p["application.process.binary"], node.name])
            if (k && appOverrides[k.toLowerCase()]) return Quickshell.iconPath(appOverrides[k.toLowerCase()].icon, true)
        const name = p["application.icon-name"] || p["application.icon_name"] || p["application.process.binary"]
        return name ? Quickshell.iconPath(name, true) : ""
    }

    // Which sink a stream currently feeds (via the link groups).
    function sinkOf(stream) {
        for (const g of Pipewire.linkGroups.values) if (g.source === stream) return g.target
        return null
    }

    // ── routing rules ──
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string sessionRulesPath: runtimeDir + "/qs-audio-routes.json"
    readonly property string persistentRulesPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/audio-routes.json"
    property var sessionRules: ({})
    property var persistentRules: ({})
    // pipewire node ids that carry an explicit target (were moved by hand)
    property var pinned: ({})

    FileView { id: sessionFile; path: root.sessionRulesPath; watchChanges: true; printErrors: false
        onFileChanged: reload(); onLoaded: { root.sessionRules = root.readRules(text()); root.applySoon() } }
    FileView { id: persistentFile; path: root.persistentRulesPath; watchChanges: true; printErrors: false
        onFileChanged: reload(); onLoaded: { root.persistentRules = root.readRules(text()); root.applySoon() } }

    function readRules(text) {
        try {
            const r = JSON.parse(text).rules ?? {}
            const out = {}
            for (const k in r) out[k] = typeof r[k] === "object" ? r[k].sink : String(r[k])
            return out
        } catch (e) { return {} }
    }
    function writeRules(view, rules) {
        const r = {}
        for (const k of Object.keys(rules).sort()) r[k] = { sink: rules[k] }
        view.setText(JSON.stringify({ rules: r }, null, 2) + "\n")
    }
    // app key -> {sink, scope}; a session rule shadows an always rule
    function rules() {
        const out = {}
        for (const k in persistentRules) out[k] = { sink: persistentRules[k], scope: "always" }
        for (const k in sessionRules) out[k] = { sink: sessionRules[k], scope: "session" }
        return out
    }
    function ruleFor(node) { return rules()[appKey(node)] ?? null }
    function setRule(key, sink, scope) {
        const s = Object.assign({}, sessionRules), p = Object.assign({}, persistentRules)
        if (scope === "session") { s[key] = sink; delete p[key] } else { p[key] = sink; delete s[key] }
        sessionRules = s; persistentRules = p
        writeRules(sessionFile, s); writeRules(persistentFile, p)
    }
    function clearRule(key) {
        const s = Object.assign({}, sessionRules), p = Object.assign({}, persistentRules)
        delete s[key]; delete p[key]
        sessionRules = s; persistentRules = p
        writeRules(sessionFile, s); writeRules(persistentFile, p)
    }

    // ── moving streams ──
    function move(stream, sinkName) {
        Proc.run(["pw-metadata", String(stream.id), "target.object", sinkName], () => root.refreshPinned())
    }
    function unpin(stream) {
        Proc.sh("pw-metadata -d " + stream.id + " target.object; pw-metadata -d " + stream.id + " target.node", () => root.refreshPinned())
    }
    function refreshPinned() {
        Proc.run(["pw-metadata", "-n", "default"], (code, out) => {
            const p = {}
            for (const line of out.split("\n")) {
                if (line.startsWith("update: id:") && line.indexOf("key:'target.") >= 0) {
                    const id = parseInt(line.split(/\s+/)[1].split(":")[1])
                    if (!isNaN(id)) p[id] = true
                }
            }
            pinned = p
        })
    }
    // Route one stream (or every stream of its app) to `sink` (null = back to the default).
    function route(stream, sinkName, scope) {
        const key = appKey(stream)
        const targets = scope === "stream" ? [stream] : streams.filter(s => appKey(s) === key)
        if (sinkName === null) {
            if (scope !== "stream") clearRule(key)
            for (const s of targets) unpin(s)
        } else {
            if (scope !== "stream") setRule(key, sinkName, scope)
            for (const s of targets) move(s, sinkName)
        }
    }
    // Apply every rule whose sink is present (or just one stream).
    function apply(only) {
        const rs = rules()
        if (!Object.keys(rs).length) return
        const present = {}
        for (const s of sinks) present[s.name] = s
        for (const st of streams) {
            if (only && st !== only) continue
            const rule = rs[appKey(st)]
            if (!rule || !present[rule.sink]) continue
            const cur = sinkOf(st)
            if (!cur || cur.name !== rule.sink) move(st, rule.sink)
        }
    }
    Timer { id: applyTimer; interval: 300; onTriggered: root.apply() }
    function applySoon() { applyTimer.restart() }

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost(obj, index) {
            if (obj.isStream && obj.isSink && obj.audio) newStream.arm(obj)
            else if (obj.isSink && !obj.isStream && obj.audio) root.applySoon()
        }
    }
    Timer {
        id: newStream
        interval: 150
        property var queue: []
        function arm(node) { queue.push(node); restart() }
        onTriggered: { const q = queue; queue = []; for (const n of q) root.apply(n); root.refreshPinned() }
    }
    Component.onCompleted: { refreshPinned(); applySoon() }
}
