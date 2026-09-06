import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Theme
import qs.Widgets
import qs.Services

// Workspaces: the per-display banks and how switching behaves.
//   Banks       which display owns which five (state/monitors.json, read by
//               lib/workspaces.lua): the primary has 1–5, the rest 11–15 and
//               21–25 left to right. SUPER+1..5 means the Nth of the display
//               under the pointer, so the numbers past 5 are never typed.
//   Behaviour   back-and-forth, cycling, centring (Hyprland options, live)
//   Special     the scratchpad's size and dimming, and the keys that toggle it
//   Gestures    the hl.gesture{} entries in conf/input.lua, read-only
//   Advanced    the map file and gen-monitors' re-deal by display size
PageBody {
    id: root
    title: "Workspaces"
    subtitle: "Five per display, dealt from the primary one"
    status: Displays.status
    statusError: Displays.statusError
    property var gestures: []
    readonly property string mainMod: { const k = Binds.keysOf("ws.focus"); return k.length ? k[0] : "SUPER" }

    Component.onCompleted: Hypr.loadSchema(false)
    onVisibleChanged: if (visible) Displays.refresh()

    // The enabled displays in dealing order (primary first, then left to right) with the workspace ids each one owns.
    readonly property var banks: {
        Displays.state; Displays.monitors
        const on = Displays.enabled.slice().sort((a, b) => Displays.logical(a.name).x - Displays.logical(b.name).x)
        const prim = on.find(m => m.name === Displays.primary)
        const order = prim ? [prim].concat(on.filter(m => m !== prim)) : on
        return order.map(m => ({
            name: m.name,
            description: m.description || "",
            primary: m.name === Displays.primary,
            ids: Object.keys(Displays.wsHome).filter(k => Displays.wsHome[k] === m.name).map(Number).sort((a, b) => a - b)
        }))
    }
    function rangeText(ids) {
        if (!ids.length) return "none"
        const contiguous = ids.every((v, i) => i === 0 || v === ids[i - 1] + 1)
        return contiguous && ids.length > 1 ? ids[0] + " – " + ids[ids.length - 1] : ids.join(", ")
    }
    function combos(id) { Binds.revision; return Binds.keysOf(id).map(Binds.prettyCombo).join("  ·  ") }
    function tilde(p) { return p.replace(Hypr.home, "~") }

    // conf/input.lua's hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" }) blocks
    FileView {
        path: Hypr.hyprDir + "/conf/input.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.gestures = root.parseGestures(text())
    }
    function parseGestures(src) {
        const out = [], re = /hl\.gesture\s*\(\s*\{([^}]*)\}\s*\)/g
        const code = src.replace(/--.*$/gm, "")
        let m
        while ((m = re.exec(code)) !== null) {
            const g = {}, kv = /(\w+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([\w.\-]+))/g
            let p
            while ((p = kv.exec(m[1])) !== null) g[p[1]] = p[2] ?? p[3] ?? p[4]
            out.push(g)
        }
        return out
    }
    function gestureLabel(g) {
        return (g.fingers ? g.fingers + "-finger " : "") + (g.direction || "swipe") + (g.mod ? " with " + g.mod : "")
    }
    function gestureValue(g) {
        return [g.action || "?", g.scale ? "× " + g.scale : "", g.float !== undefined ? "float " + g.float : ""].filter(x => x).join("  ")
    }
    // An OptionRow that steps aside when this Hyprland has no such option.
    component Opt: OptionRow { visible: hit && Hypr.schema[name] !== undefined }

    // ── banks ──
    Group {
        title: "Banks"
        hint: root.mainMod + " + 1…5 opens the Nth workspace of the display under the pointer, SHIFT moves the window there. Every display has its own five, so no key past 5 is needed; the bar relabels each bank 1–5."
        Repeater {
            model: root.banks
            SettingRow {
                required property var modelData
                label: modelData.name + (modelData.primary ? "  ★ primary" : "")
                hint: modelData.description + (modelData.ids.length ? "" : (modelData.description ? "  ·  " : "") + "no workspaces dealt to it yet; re-deal below")
                keywords: "display monitor bank " + modelData.ids.join(" ")
                value: root.rangeText(modelData.ids)
            }
        }
        SettingRow {
            visible: hit && root.banks.length === 0
            label: "No enabled displays"
            hint: "hyprctl monitors reported nothing that is on"
        }
        SettingRow {
            label: "Primary display"
            hint: "Owns workspaces 1–5; the others take 11–15 and 21–25, left to right. Changing it re-deals and reloads Hyprland."
            keywords: "main star owner"
            Picker {
                model: Displays.names.map(n => { const m = Displays.byName(n); return { text: n, value: n, hint: m ? (m.disabled ? "off" : m.description || "") : "" } })
                current: Displays.primary
                minWidth: 150
                onPicked: v => { if (v !== Displays.primary) Displays.setPrimary(v) }
            }
        }
        SettingRow {
            label: "Arrange displays"
            hint: "Positions, modes and scale on the Displays page; the left-to-right order there is the dealing order here"
            keywords: "monitors position layout"
            clickable: true
            onClicked: Overlays.openSettings("displays")
        }
    }

    // ── behaviour ──
    Group {
        title: "Behaviour"
        hint: "What switching to a workspace does"
        Opt { name: "binds:workspace_back_and_forth"; label: "Back and forth"; hint: "Pressing the key of the workspace you are on goes back to the previous one" }
        Opt { name: "binds:allow_workspace_cycles"; label: "Allow cycles"; hint: "Back and forth keeps alternating between the last two instead of stopping" }
        Opt { name: "binds:workspace_center_on"; label: "Centre on switch"; hint: "Where the pointer lands when a switch moves focus to another display" }
        Opt { name: "general:gaps_workspaces"; label: "Gap between workspaces"; hint: "Extra space between workspaces while a swipe or animation shows two at once" }
        Opt { name: "misc:initial_workspace_tracking"; label: "Open new windows where they were launched"; hint: "A window that takes a while to appear still lands on the workspace it was started from" }
    }

    // ── special workspace ──
    Group {
        title: "Special workspace"
        hint: "The scratchpad floats over the current workspace; relayout parks Spotify there"
        Opt { name: "dwindle:special_scale_factor"; label: "Scratchpad size"; hint: "How much of the screen the scratchpad covers in the dwindle layout" }
        Opt { name: "master:special_scale_factor"; label: "Scratchpad size (master layout)" }
        Opt { name: "decoration:dim_special"; label: "Dim behind the scratchpad" }
        SettingRow {
            label: "Toggle scratchpad"
            hint: (Binds.action("ws.special") ? Binds.action("ws.special").name : "ws.special") + "  ·  change it on the Keybinds page"
            keywords: "special magic key shortcut bind"
            value: root.combos("ws.special") || "not bound"
            clickable: true
            onClicked: Overlays.openSettings("keybinds")
        }
        SettingRow {
            label: "Send window to scratchpad"
            keywords: "special magic move key shortcut bind"
            value: root.combos("ws.to_special") || "not bound"
            clickable: true
            onClicked: Overlays.openSettings("keybinds")
        }
    }

    // ── gestures ──
    Group {
        title: "Gestures"
        advanced: true
        hint: "Touchpad swipes from conf/input.lua"
        Repeater {
            model: root.gestures
            SettingRow {
                required property var modelData
                label: root.gestureLabel(modelData)
                hint: "edit in conf/input.lua"
                keywords: "swipe touchpad fingers " + (modelData.action || "")
                value: root.gestureValue(modelData)
            }
        }
        SettingRow {
            visible: hit && root.gestures.length === 0
            label: "No gestures"
            hint: "add an hl.gesture({ fingers, direction, action }) block to conf/input.lua"
            keywords: "swipe touchpad fingers"
        }
    }

    // ── advanced ──
    Group {
        title: "Advanced"
        advanced: true
        SettingRow {
            label: "Workspace map file"
            hint: "ws_home: workspace id → display. lib/workspaces.lua reads it on every load; the Displays page and gen-monitors write it."
            keywords: "monitors.json state path ws_home"
            value: root.tilde(Displays.statePath)
        }
        SettingRow {
            label: "Re-deal by display size"
            hint: "gen-monitors: the biggest display becomes primary and the banks are dealt left to right; rewrites monitors.lua too and reloads"
            keywords: "gen-monitors reset automatic"
            clickable: true
            onClicked: {
                Displays.status = "re-dealing…"; Displays.statusError = false
                Proc.run([Hypr.home + "/.local/bin/gen-monitors"], (code, out, err) => {
                    Displays.status = code === 0 ? "workspaces re-dealt" : (err || out).trim() || "gen-monitors failed"
                    Displays.statusError = code !== 0
                    Displays.refresh()
                })
            }
        }
    }
}
