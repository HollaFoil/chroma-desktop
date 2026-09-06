import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Mouse: the pointer defaults, one collapsed group per pointing device, the
// touchpad, the cursor, and how the pointer focuses and scrolls.
//   Pointer            the global input:* defaults (OptionRows)
//   <each mouse>       hl.device{} overrides for that device, drawn over the
//                      defaults; ● and ↺ after a label mark an override
//   Touchpad           input:touchpad:* (kept for laptops; harmless without one)
//   Cursor             theme and size via gsettings + `hyprctl setcursor`,
//                      when the cursor hides
//   Focus & scrolling  follow_mouse, refocus, scroll method, zoom
// Hyprland lists every device with buttons under "mice" (the keyboard, the
// headset's media keys…); those go to "Other pointer-capable devices".
PageBody {
    id: root
    title: "Mouse"
    subtitle: "Pointer devices, touchpad and cursor"
    status: Hypr.schemaLoaded ? "" : "reading options…"
    Component.onCompleted: { Hypr.loadSchema(false); Hypr.refreshDevices(); loadCursor() }

    function isPointer(name) {
        const n = String(name).replace(/-\d+$/, "")
        return !/keyboard$/.test(n) && n.indexOf("consumer-control") < 0 && n.indexOf("video-bus") < 0 && n.indexOf("power-button") < 0
    }
    readonly property var pointers: Hypr.devices.mice.filter(m => isPointer(m.name))
    readonly property var others: Hypr.devices.mice.filter(m => !isPointer(m.name))
    function report(err) { root.status = err || ""; root.statusError = !!err }

    // ── cursor: gsettings owns the theme and size, Hyprland is told the same ──
    property string cursorTheme: ""
    property int cursorSize: 0
    property var cursorThemes: []
    property string cursorStatus: ""
    property bool cursorError: false
    readonly property var cursorSizes: [24, 32, 48, 64]
    readonly property var cursorChoices: {
        const list = cursorThemes.map(t => ({ text: t, value: t }))
        if (cursorTheme.length > 0 && cursorThemes.indexOf(cursorTheme) < 0) list.unshift({ text: cursorTheme, value: cursorTheme, hint: "set, but not found in the icon directories" })
        return list
    }
    function loadCursor() {
        const script = "gsettings get org.gnome.desktop.interface cursor-theme; echo @@; gsettings get org.gnome.desktop.interface cursor-size; echo @@; "
                     + "for d in /usr/share/icons \"$HOME/.local/share/icons\" \"$HOME/.icons\"; do [ -d \"$d\" ] || continue; for t in \"$d\"/*/; do [ -d \"$t/cursors\" ] && basename \"$t\"; done; done | sort -u"
        Proc.sh(script, (code, out) => {
            const p = out.split("@@").map(s => s.trim())
            root.cursorTheme = (p[0] || "").replace(/^'|'$/g, "")
            root.cursorSize = parseInt(p[1]) || 0
            root.cursorThemes = (p[2] || "").split("\n").map(s => s.trim()).filter(s => s.length > 0)
        })
    }
    function applyCursor(theme, size) {
        root.cursorError = false
        root.cursorStatus = "applying…"
        const script = "gsettings set org.gnome.desktop.interface cursor-theme \"$QS_THEME\" && gsettings set org.gnome.desktop.interface cursor-size \"$QS_SIZE\" && hyprctl setcursor \"$QS_THEME\" \"$QS_SIZE\""
        Proc.run(["sh", "-c", script], (code, out, err) => {
            const t = (err + " " + out).trim()
            if (code !== 0 || /error|invalid|fail/i.test(t)) { root.cursorStatus = t || "could not set the cursor"; root.cursorError = true }
            else root.cursorStatus = ""
            root.loadCursor()
        }, { QS_THEME: theme, QS_SIZE: String(size) })
    }

    // One per-device setting: the override when there is one, otherwise
    // `fallback` (the matching global option). ● and ↺ after the label when
    // overridden, as OptionRow does it. Errors go to the page's status line.
    component DeviceRow: SettingRow {
        id: row
        property string device: ""
        property string field: ""
        property var fallback: undefined
        readonly property bool overridden: Hypr.hasDeviceOverride(device, field)
        readonly property var cur: Hypr.deviceValue(device, field, fallback)
        keywords: device + " " + field.replace(/_/g, " ")
        function set(v) { Hypr.setDevice(device, field, v, root.report) }
        afterLabel: [
            Glyph { text: "●"; size: 8; color: Colors.tertiary; visible: row.overridden },
            IconButton { glyph: "󰦛"; kind: "action"; small: true; visible: row.overridden; implicitWidth: 22; onClicked: Hypr.resetDevice(row.device, row.field) }
        ]
    }

    Group {
        title: "Pointer"
        hint: "Defaults for every mouse; a device below can differ"
        OptionRow { name: "input:sensitivity"; label: "Speed"; hint: "0 leaves the device as it is; negative is slower" }
        OptionRow { name: "input:accel_profile"; label: "Acceleration"; hint: "Adaptive speeds up with faster movement; flat is one-to-one (gaming)" }
        OptionRow { name: "input:natural_scroll"; label: "Natural scrolling"; hint: "Content follows the wheel, as on a touchscreen" }
        OptionRow { name: "input:left_handed"; label: "Left-handed"; hint: "Swaps the left and right buttons" }
        OptionRow { name: "input:scroll_factor"; label: "Scroll speed"; hint: "Multiplier on every wheel step" }
    }

    Repeater {
        model: root.pointers
        Group {
            id: dev
            required property var modelData
            readonly property string name: modelData.name
            advanced: true
            title: Hypr.prettyDevice(name)
            hint: name
            DeviceRow {
                id: rEnabled
                device: dev.name; field: "enabled"; fallback: true
                label: "Enabled"
                hint: "Off ignores the device without unplugging it"
                Toggle { checked: rEnabled.cur === true; onToggled: v => rEnabled.set(v) }
            }
            DeviceRow {
                id: rSpeed
                device: dev.name; field: "sensitivity"; fallback: Number(Hypr.optionValue("input:sensitivity", 0))
                label: "Speed"
                hint: "-1 to 1; 0 is the device's own speed"
                Slider { id: slSpeed; from: -1; to: 1; step: 0.05; value: Number(rSpeed.cur) || 0; onMoved: v => rSpeed.set(Math.round(v * 100) / 100) }
                Label { text: slSpeed._live.toFixed(2); size: Tokens.fontSizeSmall; dim: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 44 }
            }
            DeviceRow {
                id: rAccel
                device: dev.name; field: "accel_profile"; fallback: Hypr.optionValue("input:accel_profile", "adaptive")
                label: "Acceleration"
                hint: "Flat moves the pointer exactly as far as the mouse"
                Segmented {
                    model: ["Adaptive", "Flat"]
                    current: rAccel.cur === "flat" ? 1 : (rAccel.cur === "adaptive" || rAccel.cur === "") ? 0 : -1
                    onPicked: i => rAccel.set(i === 1 ? "flat" : "adaptive")
                }
            }
            DeviceRow {
                id: rNatural
                device: dev.name; field: "natural_scroll"; fallback: Hypr.optionValue("input:natural_scroll", false) === true
                label: "Natural scrolling"
                Toggle { checked: rNatural.cur === true; onToggled: v => rNatural.set(v) }
            }
            DeviceRow {
                id: rLeft
                device: dev.name; field: "left_handed"; fallback: Hypr.optionValue("input:left_handed", false) === true
                label: "Left-handed"
                Toggle { checked: rLeft.cur === true; onToggled: v => rLeft.set(v) }
            }
            DeviceRow {
                id: rScroll
                device: dev.name; field: "scroll_factor"; fallback: Number(Hypr.optionValue("input:scroll_factor", 1))
                label: "Scroll speed"
                hint: "Multiplier on every wheel step"
                Slider { id: slScroll; from: 0.1; to: 5; step: 0.1; value: Number(rScroll.cur) || 1; onMoved: v => rScroll.set(Math.round(v * 10) / 10) }
                Label { text: slScroll._live.toFixed(1) + "×"; size: Tokens.fontSizeSmall; dim: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 44 }
            }
            SectionTitle { text: "More"; visible: !SettingsSearch.active; Layout.fillWidth: true }
            DeviceRow {
                id: rMiddle
                device: dev.name; field: "middle_button_emulation"; fallback: false
                label: "Middle-button emulation"
                hint: "Left and right pressed together count as a middle click"
                Toggle { checked: rMiddle.cur === true; onToggled: v => rMiddle.set(v) }
            }
            DeviceRow {
                id: rMethod
                device: dev.name; field: "scroll_method"; fallback: Hypr.optionValue("input:scroll_method", "")
                label: "Scroll method"
                hint: "How this device scrolls; most mice want the default"
                Picker {
                    model: [
                        { text: "Two fingers", value: "2fg" },
                        { text: "Edge", value: "edge" },
                        { text: "While a button is held", value: "on_button_down" },
                        { text: "No scrolling", value: "no_scroll" }
                    ]
                    current: rMethod.cur
                    placeholder: "Default"
                    minWidth: 180
                    onPicked: v => rMethod.set(v)
                }
            }
        }
    }

    Group {
        title: "Touchpad"
        hint: "Built-in touchpads only; a laptop's settings live here"
        advanced: true
        OptionRow { name: "input:touchpad:natural_scroll"; label: "Natural scrolling" }
        OptionRow { name: "input:touchpad:tap-to-click"; label: "Tap to click" }
        OptionRow { name: "input:touchpad:tap-and-drag"; label: "Tap and drag" }
        OptionRow { name: "input:touchpad:drag_lock"; label: "Drag lock" }
        OptionRow { name: "input:touchpad:disable_while_typing"; label: "Disable while typing" }
        OptionRow { name: "input:touchpad:scroll_factor"; label: "Scroll speed" }
        OptionRow { name: "input:touchpad:clickfinger_behavior"; label: "Click by finger count" }
        OptionRow { name: "input:touchpad:middle_button_emulation"; label: "Middle-button emulation" }
    }

    Group {
        title: "Cursor"
        hint: "The pointer's look; GTK and Hyprland are set together"
        SettingRow {
            label: "Theme"
            hint: "Cursor themes found in the icon directories"
            keywords: "cursor theme xcursor hyprcursor pointer look"
            Picker {
                model: root.cursorChoices
                current: root.cursorTheme
                minWidth: 200
                placeholder: root.cursorThemes.length ? "Choose…" : "reading…"
                onPicked: v => root.applyCursor(v, root.cursorSize || 24)
            }
        }
        SettingRow {
            label: "Size"
            hint: "In pixels, before the monitor's scale"
            keywords: "cursor size pixels big small"
            Segmented {
                model: root.cursorSizes
                current: root.cursorSizes.indexOf(root.cursorSize)
                onPicked: i => root.applyCursor(root.cursorTheme, root.cursorSizes[i])
            }
        }
        StatusLine { text: root.cursorStatus; error: root.cursorError; leftPadding: 8; Layout.fillWidth: true }
        OptionRow { name: "cursor:inactive_timeout"; label: "Hide when idle"; hint: "Seconds without movement before the cursor disappears; 0 never hides it" }
        OptionRow { name: "cursor:hide_on_key_press"; label: "Hide while typing"; hint: "Gone at the first key press, back at the next movement" }
    }

    Group {
        title: "Focus & scrolling"
        hint: "How the pointer chooses windows, and scroll handling"
        advanced: true
        OptionRow { name: "input:follow_mouse"; label: "Focus follows mouse" }
        OptionRow { name: "input:mouse_refocus"; label: "Refocus on hover" }
        OptionRow { name: "input:scroll_method"; label: "Scroll method" }
        OptionRow { name: "binds:scroll_event_delay"; label: "Scroll bind delay" }
        OptionRow { name: "cursor:no_hardware_cursors"; label: "Hardware cursors" }
        OptionRow { name: "cursor:zoom_factor"; label: "Zoom" }
        OptionRow { name: "cursor:zoom_rigid"; label: "Zoom follows rigidly" }
    }

    Group {
        id: othersGroup
        title: "Other pointer-capable devices"
        hint: "Hyprland lists these as mice because they have buttons; they are not pointers"
        advanced: true
        visible: root.others.length > 0 && (!SettingsSearch.active || hitCount > 0 || SettingsSearch.matches(title + " " + hint))
        Repeater {
            model: root.others
            SettingRow {
                required property var modelData
                label: Hypr.prettyDevice(modelData.name)
                hint: modelData.name
                keywords: "device " + modelData.name
                value: "not a pointer"
            }
        }
    }
}
