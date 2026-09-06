import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Displays: drag the outputs into place, then set the picked one's mode,
// scale, orientation and colour. Everything applies live through
// Services/Displays; changes that can black a screen out ask to be kept
// within 15 s or come back on their own.
PageBody {
    id: root
    title: "Displays"
    subtitle: "Arrangement, modes, scale, orientation and colour"
    property string sel: ""
    readonly property var m: Displays.byName(sel)
    readonly property var r: Displays.ruleOf(sel)
    readonly property var modes: Displays.modesOf(m)
    readonly property var cur: Displays.parseMode(r.mode) || (m ? { w: m.width, h: m.height, hz: m.refreshRate } : { w: 0, h: 0, hz: 0 })
    readonly property bool hdr: /^hdr/.test(r.cm || "")
    status: Displays.status
    statusError: Displays.statusError
    headerItems: [
        Pill { text: "󰑓  Refresh"; small: true; onClicked: Displays.refresh() }
    ]
    onVisibleChanged: if (visible) Displays.refresh()
    Component.onCompleted: { Hypr.loadSchema(false); pickDefault() }
    Connections { target: Displays; function onMonitorsChanged() { root.pickDefault() } }
    function pickDefault() {
        if (sel && Displays.byName(sel)) return
        sel = Displays.byName(Displays.primary) ? Displays.primary : (Displays.monitors[0] ? Displays.monitors[0].name : "")
    }
    function gcd(a, b) { return b ? gcd(b, a % b) : a }
    function aspect(w, h) { const g = gcd(w, h) || 1; let a = w / g, b = h / g; if (a === 8 && b === 5) { a = 16; b = 10 } return a + ":" + b }
    function transformName(t) { return ["Landscape", "Portrait (90°)", "Landscape, upside down", "Portrait (270°)", "Landscape, mirrored", "Portrait, mirrored (90°)", "Upside down, mirrored", "Portrait, mirrored (270°)"][t] || String(t) }

    // ── keep / revert banner ──
    Group {
        visible: Displays.countdown > 0
        title: "Keep these display settings?"
        hint: "Reverting in " + Displays.countdown + " s unless you keep them"
        glyph: "󰍹"
        trailing: [
            Pill { text: "Revert"; small: true; onClicked: Displays.revert() },
            Pill { text: "Keep"; small: true; on: true; onClicked: Displays.keep() }
        ]
    }

    // ── arrangement ──
    Group {
        title: "Arrangement"
        hint: "Drag a display to move it; snaps to its neighbours. ★ owns workspaces 1–5."
        SettingRow {
            label: ""
            keywords: "arrange position layout drag"
            wide: true
            Item {
                id: canvas
                Layout.fillWidth: true
                implicitHeight: 210
                readonly property var mons: { Displays.state; return Displays.enabled.map(x => Object.assign({ name: x.name, primary: x.name === Displays.primary }, Displays.logical(x.name))) }
                readonly property var box: {
                    if (!mons.length) return { x: 0, y: 0, w: 1, h: 1 }
                    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
                    for (const q of mons) { x0 = Math.min(x0, q.x); y0 = Math.min(y0, q.y); x1 = Math.max(x1, q.x + q.w); y1 = Math.max(y1, q.y + q.h) }
                    return { x: x0, y: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) }
                }
                readonly property real f: Math.min((width - 24) / box.w, (height - 24) / box.h)
                readonly property real ox: (width - box.w * f) / 2
                readonly property real oy: (height - box.h * f) / 2
                property var dragging: null       // { name, dx, dy } in logical px while a tile is held

                // Finish a drag: snap to the others' edges, refuse overlaps, shift everything so the layout starts at 0,0.
                function drop(name, dx, dy) {
                    const me = mons.find(q => q.name === name)
                    if (!me) return
                    let nx = Math.round(me.x + dx), ny = Math.round(me.y + dy)
                    const snap = Math.max(24, 30 / f)
                    const others = mons.filter(q => q.name !== name)
                    for (const o of others) {
                        for (const cx of [o.x + o.w, o.x - me.w, o.x, o.x + o.w - me.w]) if (Math.abs(nx - cx) < snap) { nx = cx; break }
                        for (const cy of [o.y + o.h, o.y - me.h, o.y, o.y + o.h - me.h]) if (Math.abs(ny - cy) < snap) { ny = cy; break }
                    }
                    const overlaps = others.some(o => nx < o.x + o.w && nx + me.w > o.x && ny < o.y + o.h && ny + me.h > o.y)
                    if (overlaps) { root.status = "displays cannot overlap"; return }
                    const placed = others.concat([{ name, x: nx, y: ny, w: me.w, h: me.h }])
                    const minX = Math.min(...placed.map(q => q.x)), minY = Math.min(...placed.map(q => q.y))
                    const list = placed.map(q => ({ name: q.name, position: (q.x - minX) + "x" + (q.y - minY) }))
                        .filter(it => { const old = mons.find(q => q.name === it.name); return !old || (old.x + "x" + old.y) !== it.position })
                    if (list.length) Displays.applyPositions(list)
                }
                Rectangle { anchors.fill: parent; radius: Tokens.rSm; color: Tokens.alpha(Colors.surfaceContainerLowest, 0.35) }
                Repeater {
                    model: canvas.mons
                    Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool held: canvas.dragging && canvas.dragging.name === modelData.name
                        readonly property bool on: root.sel === modelData.name
                        x: canvas.ox + (modelData.x - canvas.box.x + (held ? canvas.dragging.dx : 0)) * canvas.f
                        y: canvas.oy + (modelData.y - canvas.box.y + (held ? canvas.dragging.dy : 0)) * canvas.f
                        width: Math.max(8, modelData.w * canvas.f - 3)
                        height: Math.max(8, modelData.h * canvas.f - 3)
                        z: held ? 2 : on ? 1 : 0
                        radius: Tokens.rXs
                        color: on ? Tokens.alpha(Colors.primary, held ? 0.35 : 0.25) : (tma.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh)
                        border.width: on ? 2 : 1
                        border.color: on ? Colors.primary : Tokens.alpha(Colors.outline, 0.4)
                        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            width: parent.width - 8
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4
                                Glyph { visible: tile.modelData.primary; text: "󰓎"; size: 12; color: tile.on ? Colors.primary : Colors.tertiary }
                                Label { text: tile.modelData.name; size: Tokens.fontSizeSmall; color: tile.on ? Colors.primary : Colors.surfaceFg; elide: Text.ElideRight; Layout.maximumWidth: tile.width - 24 }
                            }
                            Label { text: tile.modelData.w + " × " + tile.modelData.h; size: Tokens.fontSizeMicro; dim: true; regular: true; Layout.alignment: Qt.AlignHCenter; visible: tile.height > 40 }
                        }
                        MouseArea {
                            id: tma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property real px: 0
                            property real py: 0
                            onPressed: mouse => { root.sel = tile.modelData.name; px = mouse.x; py = mouse.y; canvas.dragging = { name: tile.modelData.name, dx: 0, dy: 0 } }
                            onPositionChanged: mouse => { if (pressed && canvas.dragging) canvas.dragging = { name: tile.modelData.name, dx: (mouse.x - px) / canvas.f, dy: (mouse.y - py) / canvas.f } }
                            onReleased: {
                                const d = canvas.dragging; canvas.dragging = null
                                if (d && (Math.abs(d.dx) > 2 || Math.abs(d.dy) > 2)) canvas.drop(d.name, d.dx, d.dy)
                            }
                        }
                    }
                }
                Label { visible: canvas.mons.length === 0; anchors.centerIn: parent; text: "no enabled displays"; dim: true; regular: true }
            }
        }
        SettingRow {
            label: "Display"
            hint: Displays.monitors.length + " connected" + (Displays.monitors.some(x => x.disabled) ? ", " + Displays.monitors.filter(x => x.disabled).length + " off" : "")
            keywords: "select monitor output"
            Segmented {
                model: Displays.names.map(n => { const x = Displays.byName(n); return (x && x.disabled ? "󰶐 " : "") + n })
                current: Displays.names.indexOf(root.sel)
                onPicked: i => root.sel = Displays.names[i]
            }
        }
    }

    // ── the picked display ──
    Group {
        visible: !!root.m
        title: root.m ? (root.m.description || root.m.name) : ""
        hint: root.m ? root.m.name + (root.m.physicalWidth ? "  ·  " + Math.round(Math.sqrt(root.m.physicalWidth ** 2 + root.m.physicalHeight ** 2) / 25.4) + '"' : "") + (root.m.disabled ? "  ·  off" : "  ·  " + root.m.width + "×" + root.m.height + " @ " + Displays.fmtHz(root.m.refreshRate) + " Hz, scale " + root.m.scale) : ""
        glyph: "󰍹"
        SettingRow {
            label: "Enabled"
            hint: root.r.disabled ? "Off: its windows and workspaces moved to the other displays" : (Displays.enabled.length <= 1 ? "The last display stays on" : "Turning a display off moves its windows elsewhere")
            keywords: "disable off on"
            Toggle { checked: !root.r.disabled; enabled: root.r.disabled || Displays.enabled.length > 1; onToggled: v => Displays.apply(root.sel, { disabled: !v }, true) }
        }
        SettingRow {
            label: "Primary display"
            hint: "Owns workspaces 1–5; the others take 11–15 and 21–25, left to right"
            keywords: "main workspaces bank star"
            enabled: !root.r.disabled
            Toggle { checked: Displays.primary === root.sel; enabled: Displays.primary !== root.sel; onToggled: v => { if (v) Displays.setPrimary(root.sel) } }
        }
        SettingRow {
            label: "Resolution"
            hint: root.cur.w ? root.aspect(root.cur.w, root.cur.h) + "  ·  the display prefers " + (root.m && root.modes.length ? root.modes[0].w + " × " + root.modes[0].h : "?") : ""
            keywords: "size pixels mode"
            enabled: !root.r.disabled
            Picker {
                readonly property var res: {
                    const seen = {}, out = []
                    for (const md of root.modes) { const k = md.w + "x" + md.h; if (seen[k]) { seen[k] = Math.max(seen[k], md.hz); continue } seen[k] = md.hz; out.push({ k, w: md.w, h: md.h }) }
                    return out.sort((a, b) => b.w * b.h - a.w * a.h).map(o => ({ text: o.w + " × " + o.h, value: o.k, hint: root.aspect(o.w, o.h) + "  ·  up to " + Displays.fmtHz(seen[o.k]) + " Hz" }))
                }
                model: res
                current: root.cur.w + "x" + root.cur.h
                searchable: res.length > 10
                onPicked: v => {
                    const [w, h] = v.split("x").map(Number)
                    const best = root.modes.filter(md => md.w === w && md.h === h).sort((a, b) => b.hz - a.hz)[0]
                    if (best) Displays.apply(root.sel, { mode: Displays.modeString(w, h, best.hz) }, true)
                }
            }
        }
        SettingRow {
            id: rateRow
            label: "Refresh rate"
            hint: "Only the rates this display reports for " + root.cur.w + " × " + root.cur.h
            keywords: "hz hertz frequency"
            enabled: !root.r.disabled
            readonly property var rates: {
                const out = []
                for (const md of root.modes.filter(md => md.w === root.cur.w && md.h === root.cur.h)) if (!out.some(x => Displays.sameHz(x, md.hz))) out.push(md.hz)
                return out.sort((a, b) => b - a)
            }
            Segmented {
                visible: rateRow.rates.length <= 4
                model: rateRow.rates.map(h => Displays.fmtHz(h) + " Hz")
                current: rateRow.rates.findIndex(h => Displays.sameHz(h, root.cur.hz))
                onPicked: i => Displays.apply(root.sel, { mode: Displays.modeString(root.cur.w, root.cur.h, rateRow.rates[i]) }, true)
            }
            Picker {
                visible: rateRow.rates.length > 4
                model: rateRow.rates.map(h => ({ text: Displays.fmtHz(h) + " Hz", value: Displays.fmtHz(h) }))
                current: Displays.fmtHz(root.cur.hz)
                minWidth: 110
                onPicked: v => Displays.apply(root.sel, { mode: Displays.modeString(root.cur.w, root.cur.h, Number(v)) }, true)
            }
        }
        SettingRow {
            label: "Scale"
            hint: "Only scales that give whole logical pixels for " + root.cur.w + " × " + root.cur.h
            keywords: "zoom dpi hidpi fractional"
            enabled: !root.r.disabled
            Picker {
                readonly property var scales: {
                    const c = [1, 1.25, 1.5, 1.6, 1.75, 2, 2.25, 2.5, 3].filter(s => Number.isInteger(Math.round(root.cur.w / s * 1000) / 1000) && Number.isInteger(Math.round(root.cur.h / s * 1000) / 1000))
                    const now = Number(root.r.scale) || 1
                    if (!c.some(s => Math.abs(s - now) < 0.001)) c.push(now)
                    return c.sort((a, b) => a - b).map(s => ({ text: Math.round(s * 100) + " %", value: s, hint: Math.round(root.cur.w / s) + " × " + Math.round(root.cur.h / s) + " logical" }))
                }
                model: scales
                current: scales.find(o => Math.abs(o.value - (Number(root.r.scale) || 1)) < 0.001)?.value
                minWidth: 110
                onPicked: v => Displays.apply(root.sel, { scale: v }, true)
            }
        }
        SettingRow {
            label: "Orientation"
            keywords: "rotate rotation portrait landscape flip transform"
            enabled: !root.r.disabled
            Picker {
                model: [0, 1, 2, 3, 4, 5, 6, 7].map(t => ({ text: root.transformName(t), value: t }))
                current: root.r.transform
                minWidth: 190
                onPicked: v => Displays.apply(root.sel, { transform: v }, true)
            }
        }
    }

    Group {
        visible: !!root.m && !root.r.disabled
        title: "Colour & sync"
        SettingRow {
            label: "Variable refresh rate"
            hint: "Adaptive sync (FreeSync / G-Sync), if the display supports it"
            keywords: "vrr adaptive sync freesync gsync"
            Segmented {
                model: ["Off", "On", "Fullscreen only"]
                current: [0, 1, 2].indexOf(root.r.vrr)
                onPicked: i => Displays.apply(root.sel, { vrr: i }, false)
            }
        }
        SettingRow {
            label: "Colour depth"
            hint: "10-bit needs a display that really has it; screen sharing of a 10-bit output fails in some apps"
            keywords: "bit depth 10 8 bpc"
            Segmented {
                model: ["8-bit", "10-bit"]
                current: root.r.bitdepth === 10 ? 1 : 0
                onPicked: i => Displays.apply(root.sel, { bitdepth: i ? 10 : 8 }, true)
            }
        }
        SettingRow {
            label: "Colour management"
            hint: "The output's colour space. Auto picks sRGB for 8-bit and wide gamut for 10-bit."
            keywords: "color colour gamut srgb hdr wide p3 adobe cm"
            Picker {
                model: [
                    { text: "Auto", value: "auto", hint: "sRGB at 8-bit, wide gamut at 10-bit" },
                    { text: "sRGB", value: "srgb", hint: "the default" },
                    { text: "Wide gamut", value: "wide", hint: "BT.2020 primaries" },
                    { text: "Display P3", value: "dp3", hint: "Apple P3" },
                    { text: "DCI-P3", value: "dcip3" },
                    { text: "Adobe RGB", value: "adobe" },
                    { text: "From EDID", value: "edid", hint: "primaries the display reports; often inaccurate" },
                    { text: "HDR", value: "hdr", hint: "wide gamut + PQ transfer; experimental" },
                    { text: "HDR (EDID primaries)", value: "hdredid", hint: "experimental" }
                ]
                current: root.r.cm || "srgb"
                minWidth: 170
                onPicked: v => Displays.apply(root.sel, { cm: v }, /^hdr/.test(v) || /^hdr/.test(root.r.cm || ""))
            }
        }
        SettingRow {
            visible: root.hdr
            label: "SDR brightness"
            hint: "How bright ordinary (SDR) content is on an HDR output; 1.0–2.0 is typical"
            keywords: "hdr sdr brightness nits"
            Slider { id: sb; minWidth: 190; from: 0.5; to: 3; step: 0.05; value: Number(root.r.sdrbrightness) || 1; onMoved: v => Displays.apply(root.sel, { sdrbrightness: Math.round(v * 100) / 100 }, false) }
            Label { text: sb._live.toFixed(2); size: Tokens.fontSizeSmall; dim: true; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
        }
        SettingRow {
            visible: root.hdr
            label: "SDR saturation"
            keywords: "hdr sdr saturation"
            Slider { id: ss; minWidth: 190; from: 0; to: 2; step: 0.02; value: Number(root.r.sdrsaturation) || 1; onMoved: v => Displays.apply(root.sel, { sdrsaturation: Math.round(v * 100) / 100 }, false) }
            Label { text: ss._live.toFixed(2); size: Tokens.fontSizeSmall; dim: true; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
        }
    }

    Group {
        visible: !!root.m && !root.r.disabled
        title: "Position & mirroring"
        advanced: true
        SettingRow {
            id: posRow
            label: "Position"
            hint: "Top-left corner in logical pixels; dragging above does the same"
            keywords: "x y coordinates offset"
            readonly property var lg: Displays.logical(root.sel)
            Label { text: "X"; size: Tokens.fontSizeSmall; dim: true }
            Entry { Layout.preferredWidth: 72; text: String(posRow.lg.x); onEditingFinished: { const v = parseInt(text); if (!isNaN(v) && v !== posRow.lg.x) Displays.apply(root.sel, { position: v + "x" + posRow.lg.y }, false) } }
            Label { text: "Y"; size: Tokens.fontSizeSmall; dim: true }
            Entry { Layout.preferredWidth: 72; text: String(posRow.lg.y); onEditingFinished: { const v = parseInt(text); if (!isNaN(v) && v !== posRow.lg.y) Displays.apply(root.sel, { position: posRow.lg.x + "x" + v }, false) } }
        }
        SettingRow {
            label: "Mirror"
            hint: "Show another display's picture here; it is not re-rendered, so a different aspect ratio stretches"
            keywords: "clone duplicate mirror"
            Picker {
                model: [{ text: "None", value: "" }].concat(Displays.names.filter(n => n !== root.sel).map(n => ({ text: n, value: n })))
                current: root.r.mirror || ""
                onPicked: v => Displays.apply(root.sel, { mirror: v }, true)
            }
        }
    }

    Group {
        title: "Advanced"
        advanced: true
        OptionRow { name: "misc:vrr"; label: "Global VRR default"; hint: "What displays without their own setting use" }
        OptionRow { name: "render:cm_enabled"; label: "Colour management pipeline"; hint: "Needed for HDR and wide-gamut outputs; fully applies after a Hyprland restart" }
        OptionRow { name: "render:cm_auto_hdr"; label: "Auto HDR for fullscreen HDR apps" }
        OptionRow { name: "render:direct_scanout"; label: "Direct scanout" }
        SettingRow { label: "Arrange in nwg-displays"; hint: "The external tool; it writes the same monitors.lua"; keywords: "nwg"; clickable: true; onClicked: { Overlays.settingsToggle(); Proc.detach(["nwg-displays"]) } }
        SettingRow { label: "Re-deal workspaces by size"; hint: "gen-monitors: the biggest display becomes primary and the banks are dealt left to right"; keywords: "gen-monitors"; clickable: true; onClicked: Proc.run([Hypr.home + "/.local/bin/gen-monitors"], (c, out, err) => { Displays.status = c === 0 ? "workspaces re-dealt" : (err || out).trim(); Displays.statusError = c !== 0 }) }
        SettingRow { label: "Config"; value: "~/.config/hypr/monitors.lua  ·  state/monitors.json"; keywords: "file path" }
    }
}
