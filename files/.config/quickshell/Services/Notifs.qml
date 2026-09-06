pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Hyprland

// The notification daemon. Every notification becomes an entry (a plain
// object, so history survives a restart and the shell's own messages fit the
// same list): shown as a toast on the focused screen (or the one toast.screen
// names) until its timeout (toast.timeout.low / .normal, never for critical),
// then kept in the centre until dismissed. Transient ones are not kept; the
// centre holds notifs.history entries at most. Do-not-disturb keeps everything
// in the centre and shows no toasts; so does notifs.muted for the apps it lists.
Singleton {
    id: root
    property bool dnd: false
    property var items: []            // entries, newest first
    property var popups: []           // keys of entries currently shown as toasts
    readonly property int count: items.length
    property int nextKey: 1
    property int tick: 0              // bumps every 30 s so relative times refresh
    signal toastRequested(var entry)

    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/notifications.json"
    property bool loadedState: false

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true
        onNotification: n => {
            n.tracked = true
            if (n.lastGeneration) {
                // carried over a reload: reattach to the entry we already list
                const e = root.items.find(x => x.id === n.id && x.notif === null)
                if (e) { e.notif = n; root.wire(n, e); return }
                root.add(n, false)
            } else root.add(n, true)
        }
    }

    function entryFrom(n) {
        return {
            key: nextKey++, id: n.id, app: n.appName || n.desktopEntry || "notification",
            icon: n.appIcon || "", image: n.image || "", summary: n.summary || "", body: n.body || "",
            urgency: n.urgency === NotificationUrgency.Critical ? 2 : n.urgency === NotificationUrgency.Low ? 0 : 1,
            time: Date.now(), transient: !!n.transient, resident: !!n.resident,
            actions: n.actions.map(a => ({ text: a.text, id: a.identifier })), hasReply: !!n.hasInlineReply,
            replyPlaceholder: n.inlineReplyPlaceholder || "reply", notif: n,
            screen: toastScreen()
        }
    }
    // toast.screen when that output is connected, else the focused one
    function toastScreen() {
        const want = Prefs.get("toast.screen", "focused")
        if (want !== "focused" && Quickshell.screens.some(s => s.name === want)) return want
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }
    function muted(app) { return Prefs.get("notifs.muted", []).indexOf(app) >= 0 }
    readonly property int historyCap: Math.max(1, Prefs.get("notifs.history", 200))
    function wire(n, e) {
        n.closed.connect(reason => { root.remove(e.key, false) })
    }
    function add(n, fresh) {
        const e = entryFrom(n)
        wire(n, e)
        items = [e].concat(items).slice(0, historyCap)
        if (fresh && !dnd && !muted(e.app)) showToast(e)
        save()
    }
    // The shell's own messages (network changes and the like).
    function post(summary, body, icon) {
        const e = { key: nextKey++, id: -1, app: "quickshell", icon: icon || "", image: "", summary: summary, body: body || "",
                    urgency: 1, time: Date.now(), transient: true, resident: false, actions: [], hasReply: false,
                    replyPlaceholder: "", notif: null, screen: toastScreen() }
        items = [e].concat(items).slice(0, historyCap)
        if (!dnd && !muted(e.app)) showToast(e)
    }
    function showToast(e) { popups = popups.concat([e.key]); toastRequested(e) }
    function hideToast(key) {
        popups = popups.filter(k => k !== key)
        const e = items.find(x => x.key === key)
        if (e && e.transient) remove(key, false)
    }
    function entry(key) { return items.find(x => x.key === key) ?? null }
    // Drop an entry; `tell` also closes it at the source.
    function remove(key, tell) {
        const e = items.find(x => x.key === key)
        if (!e) return
        if (tell && e.notif) { const n = e.notif; e.notif = null; n.dismiss() }
        items = items.filter(x => x.key !== key)
        popups = popups.filter(k => k !== key)
        save()
    }
    function dismiss(key) { remove(key, true) }
    function clearAll() { for (const e of items.slice()) remove(e.key, true) }
    function clearApp(app) { for (const e of items.filter(x => x.app === app)) remove(e.key, true) }
    function invoke(e, actionId) {
        if (!e.notif) { remove(e.key, false); return }
        const a = e.notif.actions.find(x => x.identifier === actionId)
        if (a) a.invoke()
        if (!e.resident) remove(e.key, false)
    }
    function activate(e) {
        if (e.actions.some(a => a.id === "default")) invoke(e, "default")
        else dismiss(e.key)
    }
    function reply(e, text) {
        if (e.notif && e.hasReply && text.length) { e.notif.sendInlineReply(text); if (!e.resident) remove(e.key, false) }
    }

    function ago(ms) {
        const s = Math.max(0, Math.floor((Date.now() - ms) / 1000))
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + " min"
        if (s < 86400) return Math.floor(s / 3600) + " h"
        return Math.floor(s / 86400) + " d"
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.tick++ }

    // ── persistence ──
    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: {
            if (root.loadedState) return
            try {
                const j = JSON.parse(text())
                root.dnd = !!j.dnd
                const hist = (j.items || []).map(e => Object.assign({}, e, { notif: null, key: root.nextKey++ }))
                root.items = root.items.concat(hist.filter(h => !root.items.some(x => x.id === h.id && x.app === h.app)))
            } catch (e) {}
            root.loadedState = true
        }
        onLoadFailed: root.loadedState = true
    }
    Timer { id: saveTimer; interval: 500; onTriggered: root.saveNow() }
    function save() { saveTimer.restart() }
    function saveNow() {
        const plain = items.filter(e => !e.transient).slice(0, historyCap).map(e => ({ id: e.id, app: e.app, icon: e.icon, image: e.image, summary: e.summary, body: e.body,
                                              urgency: e.urgency, time: e.time, transient: false, resident: false, actions: [], hasReply: false, replyPlaceholder: "", screen: e.screen }))
        stateFile.setText(JSON.stringify({ dnd: dnd, items: plain }, null, 1))
    }
    onDndChanged: if (loadedState) save()
}
