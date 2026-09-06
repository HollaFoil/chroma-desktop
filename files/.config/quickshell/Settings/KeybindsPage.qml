import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Every action from the config, what it is bound to, and whether the
// cheatsheet lists it. Click a key chip (or +) and press the combination:
// the chip pulses, Hyprland is switched to the empty "capture" submap so
// SUPER + anything reaches us instead of running a bind, and the window's
// keyGrab routes the keys here. Escape cancels. A click on the pulsing chip
// with a modifier held records a mouse bind. For a parametrised action
// (SUPER + 1-0) only the modifiers are kept.
//
// Every change rewrites state/keybinds.json and reloads Hyprland; the page
// follows the config's fresh export (Binds), so it shows what the compositor
// actually has. "Run a command" actions live in the same file.
PageBody {
    id: root
    property var host: null                 // the OverlayWindow (for keyGrab)
    title: "Keybinds"
    subtitle: "Every action and the keys that trigger it"
    property var capture: null              // { action, index } while recording
    property bool formOpen: false
    property string formCategory: Binds.categories.length ? Binds.categories[0] : "Utilities"
    headerItems: [ Pill { text: "󰐕  Add command"; small: true; on: root.formOpen; onClicked: { root.formOpen = !root.formOpen; if (root.formOpen) fName.input.forceActiveFocus() } } ]

    readonly property var modKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr,
                                    Qt.Key_CapsLock, Qt.Key_NumLock, Qt.Key_ScrollLock, Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_Mode_switch]
    readonly property var shifted: ({ "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
                                      "_": "minus", "+": "equal", "{": "bracketleft", "}": "bracketright", "|": "backslash", ":": "semicolon",
                                      "\"": "apostrophe", "<": "comma", ">": "period", "?": "slash", "~": "grave" })
    readonly property var names: {
        const n = {}
        n[Qt.Key_Space] = "space"; n[Qt.Key_Return] = "Return"; n[Qt.Key_Enter] = "KP_Enter"; n[Qt.Key_Tab] = "TAB"; n[Qt.Key_Backtab] = "TAB"
        n[Qt.Key_Backspace] = "BackSpace"; n[Qt.Key_Delete] = "Delete"; n[Qt.Key_Insert] = "Insert"; n[Qt.Key_Home] = "Home"; n[Qt.Key_End] = "End"
        n[Qt.Key_PageUp] = "Prior"; n[Qt.Key_PageDown] = "Next"; n[Qt.Key_Left] = "Left"; n[Qt.Key_Right] = "Right"; n[Qt.Key_Up] = "Up"; n[Qt.Key_Down] = "Down"
        n[Qt.Key_Print] = "Print"; n[Qt.Key_Minus] = "minus"; n[Qt.Key_Equal] = "equal"; n[Qt.Key_BracketLeft] = "bracketleft"; n[Qt.Key_BracketRight] = "bracketright"
        n[Qt.Key_Backslash] = "backslash"; n[Qt.Key_Semicolon] = "semicolon"; n[Qt.Key_Apostrophe] = "apostrophe"; n[Qt.Key_Comma] = "comma"
        n[Qt.Key_Period] = "period"; n[Qt.Key_Slash] = "slash"; n[Qt.Key_QuoteLeft] = "grave"; n[Qt.Key_Escape] = "Escape"
        n[Qt.Key_VolumeUp] = "XF86AudioRaiseVolume"; n[Qt.Key_VolumeDown] = "XF86AudioLowerVolume"; n[Qt.Key_VolumeMute] = "XF86AudioMute"
        n[Qt.Key_MicMute] = "XF86AudioMicMute"; n[Qt.Key_MonBrightnessUp] = "XF86MonBrightnessUp"; n[Qt.Key_MonBrightnessDown] = "XF86MonBrightnessDown"
        n[Qt.Key_MediaPlay] = "XF86AudioPlay"; n[Qt.Key_MediaPause] = "XF86AudioPause"; n[Qt.Key_MediaTogglePlayPause] = "XF86AudioPlay"
        n[Qt.Key_MediaNext] = "XF86AudioNext"; n[Qt.Key_MediaPrevious] = "XF86AudioPrev"; n[Qt.Key_MediaStop] = "XF86AudioStop"
        return n
    }
    function keyName(ev) {
        if (modKeys.indexOf(ev.key) >= 0) return null
        if (ev.key >= Qt.Key_F1 && ev.key <= Qt.Key_F35) return "F" + (ev.key - Qt.Key_F1 + 1)
        if ((ev.key >= Qt.Key_A && ev.key <= Qt.Key_Z) || (ev.key >= Qt.Key_0 && ev.key <= Qt.Key_9)) return String.fromCharCode(ev.key)
        if (names[ev.key]) return names[ev.key]
        if (ev.text && shifted[ev.text]) return shifted[ev.text]
        if (ev.text && ev.text.length === 1 && ev.text.trim().length) return ev.text
        return null
    }
    function modsOf(m) {
        const out = []
        if (m & Qt.MetaModifier) out.push("SUPER")
        if (m & Qt.ControlModifier) out.push("CTRL")
        if (m & Qt.AltModifier) out.push("ALT")
        if (m & Qt.ShiftModifier) out.push("SHIFT")
        return out
    }
    readonly property var mouseButtons: ({ [Qt.LeftButton]: "mouse:272", [Qt.RightButton]: "mouse:273", [Qt.MiddleButton]: "mouse:274", [Qt.BackButton]: "mouse:275", [Qt.ForwardButton]: "mouse:276" })

    // ── capture ──
    function beginCapture(action, index) {
        if (capture) endCapture()
        capture = { action, index }
        Hypr.dispatchLua('hl.dsp.submap("capture")')
        if (host) host.keyGrab = root.onKey
        status = action.name + ": " + (action.parametrised ? "press the modifiers and a key" : "press a key combination") + " · Escape cancels · click the chip with a mouse button for a mouse bind"
        statusError = false
    }
    function endCapture() {
        capture = null
        if (host) host.keyGrab = null
        Hypr.dispatchLua('hl.dsp.submap("reset")')
        status = ""
    }
    function onKey(ev) {
        if (ev.key === Qt.Key_Escape) { endCapture(); return true }
        const key = keyName(ev)
        if (key === null) return true
        record(modsOf(ev.modifiers), key)
        return true
    }
    function recordMouse(button, modifiers) {
        record(modsOf(modifiers), mouseButtons[button] || ("mouse:" + (271 + button)))
    }
    function normalise(combo) { const p = combo.split("+").map(s => s.trim()); return p.slice(0, -1).map(s => s.toUpperCase()).sort().join("+") + "|" + (p.length ? p[p.length - 1].toUpperCase() : "") }
    function expanded(a) {
        const out = []
        for (const key of (a.keys || [])) {
            if (a.parametrised) for (const pk of (a.param_keys || [])) out.push(normalise(key ? key + " + " + pk : pk))
            else out.push(normalise(key))
        }
        return out
    }
    function record(mods, key) {
        const { action, index } = capture
        const combo = action.parametrised ? mods.join(" + ") : mods.concat([key]).join(" + ")
        endCapture()
        const keys = (action.keys || []).slice()
        if (index === null || index === undefined) keys.push(combo); else keys[index] = combo
        saveKeys(action, keys)
        const used = expanded(Object.assign({}, action, { keys: [combo] }))
        const clashes = Binds.actions.filter(o => o.id !== action.id && expanded(o).some(c => used.indexOf(c) >= 0)).map(o => o.name)
        if (clashes.length) { status = combo + " is also bound to: " + clashes.join(", ") + " (both will run)"; statusError = true }
    }

    // ── writes ──
    function saveKeys(a, keys) {
        const data = Hypr.keybindsCopy()
        if (a.custom) { for (const c of data.custom) if (c.id === a.id) c.keys = keys }
        else {
            const entry = data.binds[a.id] || {}
            if (JSON.stringify(keys) === JSON.stringify(a.default_keys || [])) delete entry.keys; else entry.keys = keys
            if (Object.keys(entry).length) data.binds[a.id] = entry; else delete data.binds[a.id]
        }
        Hypr.saveKeybinds(data)
    }
    function removeKey(a, index) { const keys = (a.keys || []).slice(); if (index >= 0 && index < keys.length) { keys.splice(index, 1); saveKeys(a, keys) } }
    function setCheatsheet(a, on) {
        const data = Hypr.keybindsCopy()
        if (a.custom) { for (const c of data.custom) if (c.id === a.id) c.cheatsheet = on }
        else { const e = data.binds[a.id] || {}; e.cheatsheet = on; data.binds[a.id] = e }
        Hypr.saveKeybinds(data)
    }
    function resetAction(a) { const data = Hypr.keybindsCopy(); delete data.binds[a.id]; Hypr.saveKeybinds(data) }
    function deleteCustom(a) { const data = Hypr.keybindsCopy(); data.custom = data.custom.filter(c => c.id !== a.id); delete data.binds[a.id]; Hypr.saveKeybinds(data) }
    function addCustom() {
        const name = fName.text.trim(), cmd = fCmd.text.trim()
        if (!name || !cmd) { status = "a command action needs a name and a command"; statusError = true; return }
        const data = Hypr.keybindsCopy()
        const id = "custom." + Math.floor(Math.random() * 0xffffff).toString(16).padStart(6, "0")
        data.custom.push({ id, name, category: formCategory, command: cmd, keys: [], cheatsheet: true })
        fName.text = ""; fCmd.text = ""; formOpen = false
        Hypr.saveKeybinds(data)
        status = "added " + name + ": click 󰐕 on its row to bind a key"; statusError = false
    }
    Component.onDestruction: if (capture) endCapture()
    onVisibleChanged: if (!visible && capture) endCapture()

    // ── the "Run a command" form ──
    Revealer {
        open: root.formOpen
        Layout.fillWidth: true
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 6; Layout.rightMargin: 8
            implicitHeight: form.implicitHeight + 20
            radius: Tokens.rMd
            color: Tokens.alpha(Colors.surfaceContainerHigh, 0.6)
            ColumnLayout {
                id: form
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 6
                Entry { id: fName; Layout.fillWidth: true; placeholder: "name, as shown on the cheatsheet" }
                Entry { id: fCmd; Layout.fillWidth: true; placeholder: "command, run with sh -c"; onAccepted: root.addCustom() }
                RowLayout {
                    Layout.fillWidth: true
                    Segmented { model: Binds.categories; current: Binds.categories.indexOf(root.formCategory); onPicked: i => root.formCategory = Binds.categories[i]; Layout.fillWidth: true }
                    Pill { text: "Add"; small: true; on: true; onClicked: root.addCustom() }
                }
            }
        }
    }

    // ── the rows ──
    readonly property var byCategory: {
        const cats = {}
        for (const a of Binds.actions) (cats[a.category] = cats[a.category] || []).push(a)
        const order = Binds.categories.filter(c => cats[c]).concat(Object.keys(cats).filter(c => Binds.categories.indexOf(c) < 0))
        return order.map(c => ({ name: c, actions: cats[c] }))
    }
    Repeater {
        model: root.byCategory
        Group {
            id: cat
            required property var modelData
            title: cat.modelData.name
            Repeater {
                model: cat.modelData.actions
                // a custom row, but it takes part in the Group's hairlines and the search like a SettingRow
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var a: modelData
                    readonly property bool overridden: (Hypr.keybinds.binds || {})[a.id] !== undefined
                    readonly property bool isSettingRow: true
                    readonly property bool hit: SettingsSearch.matches(a.name + " " + (a.keys || []).map(k => Binds.prettyCombo(k)).join(" ") + " " + (a.command || "") + " " + a.category)
                    property bool lineAbove: false
                    visible: hit
                    Layout.fillWidth: true
                    implicitHeight: Math.max(34, r.implicitHeight + 10)
                    radius: Tokens.rSm
                    color: rh.containsMouse ? Tokens.alpha(Colors.surfaceFg, 0.04) : "transparent"
                    Component.onCompleted: { let p = parent; while (p) { if (p.addWords !== undefined && p.settingsPageIndex !== undefined) { p.addWords(a.name + " " + (a.command || "")); break } p = p.parent } }
                    Rectangle { visible: row.lineAbove; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 } height: 1; color: Tokens.alpha(Colors.outlineVariant, 0.35) }
                    MouseArea { id: rh; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    RowLayout {
                        id: r
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                        spacing: 8
                        ColumnLayout {
                            Layout.preferredWidth: 280
                            Layout.maximumWidth: 280
                            spacing: 0
                            Label { text: row.a.name; Layout.fillWidth: true }
                            Label { visible: !!row.a.custom; text: row.a.command || ""; size: Tokens.fontSizeTiny; dim: true; regular: true; Layout.fillWidth: true }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: row.a.keys || []
                                KeyChip {
                                    required property string modelData
                                    required property int index
                                    text: row.a.parametrised ? (modelData ? modelData + " + " : "") : (modelData ? Binds.prettyCombo(modelData) : "(none)")
                                    param: row.a.parametrised ? (row.a.params_label || "") : ""
                                    capturing: root.capture !== null && root.capture.action.id === row.a.id && root.capture.index === index
                                    onClicked: root.beginCapture(row.a, index)
                                    onPressedWith: (button, modifiers) => root.recordMouse(button, modifiers)
                                    onRemoved: root.removeKey(row.a, index)
                                }
                            }
                            IconButton {
                                glyph: "󰐕"; kind: "action"; small: true
                                busy: root.capture !== null && root.capture.action.id === row.a.id && root.capture.index === null
                                onClicked: root.beginCapture(row.a, null)
                            }
                        }
                        IconButton { glyph: "󰦛"; kind: "action"; small: true; visible: row.overridden && !row.a.custom; onClicked: root.resetAction(row.a) }
                        IconButton { glyph: "󰆴"; kind: "danger"; small: true; visible: !!row.a.custom; onClicked: root.deleteCustom(row.a) }
                        Check { checked: row.a.cheatsheet !== false; text: "sheet"; onToggled: v => root.setCheatsheet(row.a, v) }
                    }
                }
            }
        }
    }
}
