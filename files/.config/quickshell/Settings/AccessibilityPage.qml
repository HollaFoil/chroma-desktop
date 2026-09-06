import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Accessibility: only what this stack can honestly do.
//     Seeing    text size (gsettings text-scaling-factor), cursor size
//               (gsettings + hyprctl setcursor), screen zoom (cursor:zoom_factor)
//     Motion    animations on/off and the two "animate while dragging" switches
//     Pointer   hide the cursor on typing / after idling; link to the Mouse page
//     Typing    key repeat; sticky and slow keys are marked unavailable
// There is no xkb accessibility daemon, screen reader or bell on this Wayland
// session, so nothing pretends to switch those on.
PageBody {
    id: root
    title: "Accessibility"
    subtitle: "Text size, motion and pointer aids"
    readonly property var cursorSizes: [24, 32, 48, 64]
    property real textScale: 1.0
    property int cursorSize: 24
    property string cursorTheme: ""
    readonly property var zoomAction: Binds.actions.find(a => /zoom/i.test(String(a.id) + " " + String(a.name))) ?? null

    Component.onCompleted: { Hypr.loadSchema(false); readGsettings() }
    status: Hypr.schemaLoaded ? "" : "reading options…"

    function readGsettings() {
        Proc.sh("gsettings get org.gnome.desktop.interface text-scaling-factor; echo @@; gsettings get org.gnome.desktop.interface cursor-size; echo @@; gsettings get org.gnome.desktop.interface cursor-theme", (code, out) => {
            const p = out.split("@@").map(s => s.trim())
            const ts = parseFloat(p[0]); if (!isNaN(ts)) root.textScale = ts
            const cs = parseInt(p[1]); if (!isNaN(cs)) root.cursorSize = cs
            root.cursorTheme = (p[2] || "").replace(/^'|'$/g, "")
        })
    }
    function setTextScale(v) {
        const val = Math.round(v * 20) / 20
        root.textScale = val
        Proc.run(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", val.toFixed(2)], (code, out, err) => {
            if (code !== 0) { root.status = "gsettings failed: " + (err || out).trim(); root.statusError = true }
        })
    }
    function setCursorSize(n) {
        const theme = (cursorTheme && cursorTheme !== "default") ? cursorTheme : (Quickshell.env("XCURSOR_THEME") || cursorTheme || "default")
        root.cursorSize = n
        Proc.sh("gsettings set org.gnome.desktop.interface cursor-size " + n + " && hyprctl setcursor " + JSON.stringify(theme) + " " + n, (code, out, err) => {
            const t = (out + err).trim()
            root.statusError = code !== 0
            root.status = code === 0 ? "cursor " + n + " px (" + theme + "); apps pick it up when they next start" : "cursor size: " + (t || "failed")
        })
    }

    Group {
        title: "Seeing"
        hint: "Bigger text and pointer, and a magnifier around the pointer"
        SettingRow {
            label: "Text size"
            hint: "Scales the text of GTK apps and the shell (text-scaling-factor); apps follow as they redraw"
            keywords: "large text scaling font bigger dpi"
            Slider {
                id: textSlider
                from: 1.0; to: 2.0; step: 0.05
                value: root.textScale
                onMoved: v => root.setTextScale(v)
            }
            Label { text: Math.round(textSlider._live * 100) + "%"; size: Tokens.fontSizeSmall; dim: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 44 }
        }
        SettingRow {
            label: "Cursor size"
            hint: "Hyprland's own cursor changes at once, apps at their next start. XCURSOR_SIZE in conf/env.lua still pins Qt apps"
                  + (root.cursorSizes.indexOf(root.cursorSize) < 0 ? "  ·  now " + root.cursorSize + " px" : "")
            keywords: "pointer big mouse arrow"
            Segmented {
                model: root.cursorSizes.map(s => s + " px")
                current: root.cursorSizes.indexOf(root.cursorSize)
                onPicked: i => root.setCursorSize(root.cursorSizes[i])
            }
        }
        OptionRow {
            name: "cursor:zoom_factor"
            label: "Screen zoom"
            hint: "Magnifies the screen around the pointer; 1 is no zoom. "
                  + (root.zoomAction && (root.zoomAction.keys || []).length
                     ? "Bound to " + root.zoomAction.keys.map(Binds.prettyCombo).join(", ")
                     : "No key is bound to it; add an action for cursor:zoom_factor on the Keybinds page to toggle it")
            keywords: "magnifier magnify enlarge"
            visible: hit && Hypr.schema["cursor:zoom_factor"] !== undefined
        }
    }

    Group {
        title: "Motion"
        hint: "For motion sensitivity, or a machine that struggles to keep up"
        OptionRow { name: "animations:enabled"; label: "Animations"; hint: "Turn off to stop every window and workspace animation"; keywords: "reduce motion"; visible: hit && Hypr.schema["animations:enabled"] !== undefined }
        OptionRow { name: "misc:animate_manual_resizes"; label: "Animate manual resizes"; visible: hit && Hypr.schema["misc:animate_manual_resizes"] !== undefined }
        OptionRow { name: "misc:animate_mouse_windowdragging"; label: "Animate windows while dragging"; visible: hit && Hypr.schema["misc:animate_mouse_windowdragging"] !== undefined }
    }

    Group {
        title: "Pointer"
        OptionRow { name: "cursor:hide_on_key_press"; label: "Hide cursor while typing"; hint: "Hidden after any key press until the mouse moves"; visible: hit && Hypr.schema["cursor:hide_on_key_press"] !== undefined }
        OptionRow { name: "cursor:inactive_timeout"; label: "Hide cursor after idling"; hint: "Seconds of no pointer movement before it disappears; 0 never hides"; visible: hit && Hypr.schema["cursor:inactive_timeout"] !== undefined }
        SettingRow {
            label: "Pointer speed and acceleration"
            hint: "On the Mouse page, with the touchpad and scrolling"
            keywords: "sensitivity accel flat profile touchpad"
            clickable: true
            onClicked: Overlays.openSettings("mouse")
        }
    }

    Group {
        title: "Typing"
        OptionRow { name: "input:repeat_delay"; label: "Repeat delay"; hint: "Milliseconds a key is held before it starts repeating"; visible: hit && Hypr.schema["input:repeat_delay"] !== undefined }
        OptionRow { name: "input:repeat_rate"; label: "Repeat rate"; hint: "Repeats per second while a key is held"; visible: hit && Hypr.schema["input:repeat_rate"] !== undefined }
        SettingRow {
            label: "Sticky and slow keys"
            hint: "Not available in Hyprland; there is no xkb accessibility daemon on Wayland here"
            keywords: "bounce keys accessx modifiers"
            value: "unavailable"
        }
    }
}
