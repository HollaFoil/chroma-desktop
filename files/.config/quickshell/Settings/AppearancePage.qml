import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Appearance: the parts of the look a person actually changes.
//   Theme      the wallpaper and the palette matugen drew from it, the colour
//              scheme, GTK / icon / cursor themes (gsettings, cursor also told
//              to Hyprland with `hyprctl setcursor`)
//   Fonts      interface and monospace fonts and text scaling (gsettings);
//              the shell's own font is a token, shown read-only
//   Windows    rounding, borders, opacity, dimming (Hyprland options, live)
//   Blur / Shadow / Animations / Rendering   more Hyprland options
// Colours are never picked here: conf/look.lua and every template read the
// palette setwall renders, so a colour is changed by changing the wallpaper.
// gsettings values are read on every show, because setwall's matugen run
// resets gtk-theme to adw-gtk3-matugen (matugen/config.toml).
PageBody {
    id: root
    title: "Appearance"
    subtitle: "Theme, fonts and window decoration; colours follow the wallpaper"

    // ── gsettings state ──
    property string gtkTheme: ""
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24
    property string fontFamily: ""
    property int fontSize: 10
    property string monoFamily: ""
    property int monoSize: 10
    property real textScale: 1.0
    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []
    property var fontFamilies: []
    property string note: ""
    property bool noteError: false
    property string hoverCaption: "hover a swatch for its role and hex"
    readonly property var cursorSizes: [24, 32, 48, 64]
    readonly property var fontSizes: [9, 10, 11, 12, 13, 14]
    readonly property var swatches: [["primary", Colors.primary], ["secondary", Colors.secondary], ["tertiary", Colors.tertiary], ["error", Colors.error],
                                     ["primary container", Colors.primaryContainer], ["surface", Colors.surface], ["surface container high", Colors.surfaceContainerHigh],
                                     ["on surface", Colors.surfaceFg], ["outline", Colors.outline]]

    status: Hypr.schemaLoaded ? note : "reading options…"
    statusError: noteError
    Component.onCompleted: { Hypr.loadSchema(false); load() }
    onVisibleChanged: if (visible) { load(); Wallpapers.refresh() }

    // "Noto Sans  10" -> { family: "Noto Sans", size: 10 }
    function splitFont(s) {
        const m = /^(.*?)\s+(\d+(?:\.\d+)?)$/.exec(s.trim())
        return m ? { family: m[1].trim(), size: Math.round(parseFloat(m[2])) } : { family: s.trim(), size: 10 }
    }
    function unquote(s) { return (s || "").trim().replace(/^'|'$/g, "") }
    function lines(s) { return (s || "").split("\n").map(x => x.trim()).filter(x => x.length > 0) }
    function load() {
        const gs = k => "gsettings get org.gnome.desktop.interface " + k + "; echo @@; "
        const script = gs("gtk-theme") + gs("icon-theme") + gs("cursor-theme") + gs("cursor-size") + gs("font-name") + gs("monospace-font-name") + gs("text-scaling-factor")
            + 'for d in /usr/share/themes "$HOME/.themes" "$HOME/.local/share/themes"; do [ -d "$d" ] || continue; for t in "$d"/*/; do [ -d "$t/gtk-3.0" ] && basename "$t"; done; done | sort -u; echo @@; '
            + 'for d in /usr/share/icons "$HOME/.icons" "$HOME/.local/share/icons"; do [ -d "$d" ] || continue; for t in "$d"/*/; do [ -f "$t/index.theme" ] && [ ! -d "$t/cursors" ] && basename "$t"; done; done | sort -u; echo @@; '
            + 'for d in /usr/share/icons "$HOME/.icons" "$HOME/.local/share/icons"; do [ -d "$d" ] || continue; for t in "$d"/*/; do [ -d "$t/cursors" ] && basename "$t"; done; done | sort -u; echo @@; '
            + "fc-list : family | sort -u"
        Proc.sh(script, (code, out) => {
            const p = out.split("@@")
            root.gtkTheme = unquote(p[0]); root.iconTheme = unquote(p[1]); root.cursorTheme = unquote(p[2])
            const cs = parseInt(p[3]); if (!isNaN(cs)) root.cursorSize = cs
            const f = splitFont(unquote(p[4])); root.fontFamily = f.family; root.fontSize = f.size
            const mf = splitFont(unquote(p[5])); root.monoFamily = mf.family; root.monoSize = mf.size
            const ts = parseFloat(p[6]); if (!isNaN(ts)) root.textScale = ts
            root.gtkThemes = lines(p[7])
            root.iconThemes = lines(p[8]).filter(t => t !== "hicolor" && t !== "default")   // the fallback base and the cursor alias, not themes to pick
            root.cursorThemes = lines(p[9])
            // fc-list prints aliases after a comma ("DejaVu Sans,DejaVu Sans Condensed"): keep the first name
            const fams = {}
            for (const l of lines(p[10])) { const n = l.split(",")[0].trim(); if (n) fams[n] = true }
            root.fontFamilies = Object.keys(fams).sort((a, b) => a.localeCompare(b))
        })
    }
    function gset(key, value) {
        Proc.run(["gsettings", "set", "org.gnome.desktop.interface", key, value], (code, out, err) => {
            root.noteError = code !== 0
            root.note = code === 0 ? "" : "gsettings " + key + ": " + (err || out).trim()
            root.load()
        })
    }
    function setCursor(theme, size) {
        root.cursorTheme = theme; root.cursorSize = size
        const script = 'gsettings set org.gnome.desktop.interface cursor-theme "$QS_THEME" && gsettings set org.gnome.desktop.interface cursor-size "$QS_SIZE" && hyprctl setcursor "$QS_THEME" "$QS_SIZE"'
        Proc.run(["sh", "-c", script], (code, out, err) => {
            const t = (err + " " + out).trim()
            root.noteError = code !== 0 || /error|invalid|fail/i.test(t)
            root.note = root.noteError ? (t || "could not set the cursor") : "cursor " + theme + " " + size + " px; apps pick it up when they next start"
            root.load()
        }, { QS_THEME: theme, QS_SIZE: String(size) })
    }
    // Pickers list the set value even when no directory was found for it, so the control never shows "Choose…" for a real setting.
    function choices(list, current, missingHint) {
        const out = list.map(t => ({ text: t, value: t }))
        if (current.length > 0 && list.indexOf(current) < 0) out.unshift({ text: current, value: current, hint: missingHint })
        return out
    }
    function sizeChoices(current) {
        const s = fontSizes.slice(); if (s.indexOf(current) < 0) s.push(current)
        return s.sort((a, b) => a - b).map(n => ({ text: n + " pt", value: n }))
    }
    // An OptionRow that steps aside when this Hyprland has no such option.
    component Opt: OptionRow { visible: hit && Hypr.schema[name] !== undefined }

    // ── theme ──
    Group {
        title: "Theme"
        hint: "matugen draws the palette from the wallpaper and rewrites every theme file; nothing here picks a colour by hand"
        SettingRow {
            id: wallRow
            label: "Wallpaper and palette"
            hint: Wallpapers.current.length ? Wallpapers.stem(Wallpapers.current) : "no wallpaper reported by awww"
            keywords: "background image matugen colours colors palette swatch setwall"
            wide: true
            Rectangle {
                Layout.preferredWidth: 160; Layout.preferredHeight: 90
                radius: Tokens.rXs
                color: Colors.surfaceContainerHigh
                clip: true
                Image {
                    anchors.fill: parent
                    visible: Wallpapers.current.length > 0
                    source: Wallpapers.current.length ? "file://" + Wallpapers.current : ""
                    sourceSize.width: 320; sourceSize.height: 180
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Glyph { anchors.centerIn: parent; visible: Wallpapers.current.length === 0; text: "󰸉"; color: Colors.surfaceVariantFg }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                spacing: 6
                Row {
                    spacing: 4
                    Repeater {
                        model: root.swatches
                        Rectangle {
                            required property var modelData
                            width: 26; height: 18; radius: 5
                            color: modelData[1]
                            border.width: 1; border.color: sma.containsMouse ? Colors.surfaceFg : Tokens.alpha(Colors.outline, 0.35)
                            Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
                            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onEntered: root.hoverCaption = parent.modelData[0] + "  " + parent.modelData[1].toString() }
                        }
                    }
                }
                Label { text: root.hoverCaption; size: Tokens.fontSizeTiny; dim: true; regular: true }
            }
            Item { Layout.fillWidth: true }
            Pill { text: "󰸉  Change wallpaper"; small: true; Layout.alignment: Qt.AlignVCenter; onClicked: Overlays.openSettings("wallpapers") }
        }
        SettingRow {
            label: "Colour scheme"
            hint: "setwall runs matugen in dark mode; light needs a flag in ~/.local/bin/setwall"
            keywords: "dark light mode color colour scheme"
            value: Colors.mode === "light" ? "Light" : "Dark"
        }
        SettingRow {
            label: "GTK theme"
            hint: "adw-gtk3-matugen is adw-gtk3-dark plus the palette (~/.local/share/themes); setwall sets it again on every wallpaper change"
            keywords: "gtk3 gtk4 libadwaita adw widgets"
            Picker {
                model: root.choices(root.gtkThemes, root.gtkTheme, "set, but no gtk-3.0 directory found for it")
                current: root.gtkTheme
                minWidth: 170
                onPicked: v => { root.gtkTheme = v; root.gset("gtk-theme", v) }
            }
        }
        SettingRow {
            label: "Icon theme"
            hint: "Matugen is Adwaita with its blues swapped for the primary, rebuilt at every wallpaper change (matugen-icons)"
            keywords: "icons folders adwaita breeze"
            Picker {
                model: root.choices(root.iconThemes, root.iconTheme, "set, but not found in the icon directories")
                current: root.iconTheme
                minWidth: 170
                onPicked: v => { root.iconTheme = v; root.gset("icon-theme", v) }
            }
        }
        SettingRow {
            label: "Cursor theme"
            hint: "Hyprland's own cursor changes at once, GTK apps at their next start"
            keywords: "pointer mouse arrow xcursor hyprcursor"
            Picker {
                model: root.choices(root.cursorThemes, root.cursorTheme, "set, but no cursors/ directory found for it")
                current: root.cursorTheme
                minWidth: 170
                onPicked: v => root.setCursor(v, root.cursorSize)
            }
        }
        SettingRow {
            label: "Cursor size"
            hint: "GTK apps pick it up when they next start; conf/env.lua sets XCURSOR_SIZE for new apps, so a Hyprland restart pins the rest"
                  + (root.cursorSizes.indexOf(root.cursorSize) < 0 ? "  ·  now " + root.cursorSize + " px" : "")
            keywords: "pointer big small px"
            Segmented {
                model: root.cursorSizes.map(s => s + " px")
                current: root.cursorSizes.indexOf(root.cursorSize)
                onPicked: i => root.setCursor(root.cursorTheme, root.cursorSizes[i])
            }
        }
    }

    // ── fonts ──
    Group {
        title: "Fonts"
        hint: "What GTK apps and the shell's text scaling use (gsettings)"
        SettingRow {
            label: "Interface font"
            hint: "font-name: the default for GTK apps and their titles"
            keywords: "ui family typeface sans size"
            Picker {
                model: root.fontFamilies.map(f => ({ text: f, value: f }))
                current: root.fontFamily
                searchable: true
                minWidth: 190
                onPicked: v => { root.fontFamily = v; root.gset("font-name", v + " " + root.fontSize) }
            }
            Picker {
                model: root.sizeChoices(root.fontSize)
                current: root.fontSize
                minWidth: 72
                onPicked: v => { root.fontSize = v; root.gset("font-name", root.fontFamily + " " + v) }
            }
        }
        SettingRow {
            label: "Monospace font"
            hint: "monospace-font-name: text editors and terminals that follow the desktop setting"
            keywords: "mono code terminal fixed width"
            Picker {
                model: root.fontFamilies.map(f => ({ text: f, value: f }))
                current: root.monoFamily
                searchable: true
                minWidth: 190
                onPicked: v => { root.monoFamily = v; root.gset("monospace-font-name", v + " " + root.monoSize) }
            }
            Picker {
                model: root.sizeChoices(root.monoSize)
                current: root.monoSize
                minWidth: 72
                onPicked: v => { root.monoSize = v; root.gset("monospace-font-name", root.monoFamily + " " + v) }
            }
        }
        SettingRow {
            label: "Text scaling"
            hint: "Scales all GTK text (text-scaling-factor); apps follow as they redraw"
            keywords: "large text dpi zoom bigger smaller percent"
            Slider {
                id: scaleSlider
                from: 0.8; to: 1.5; step: 0.05
                value: root.textScale
                onMoved: v => { const val = Math.round(v * 20) / 20; root.textScale = val; root.gset("text-scaling-factor", val.toFixed(2)) }
            }
            Label { text: Math.round(scaleSlider._live * 100) + "%"; size: Tokens.fontSizeSmall; dim: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 44 }
        }
        SettingRow {
            label: "Shell font"
            hint: "set in quickshell/Theme/Tokens.qml"
            keywords: "bar quickshell nerd font tokens"
            value: Tokens.fontFamily
        }
    }

    // ── windows ──
    Group {
        title: "Windows"
        hint: "Border colours come from the palette (conf/look.lua)"
        Opt { name: "decoration:rounding"; label: "Corner radius" }
        Opt { name: "decoration:rounding_power"; label: "Corner curve"; hint: "2 is a circle; higher squares the corners off" }
        Opt { name: "general:border_size"; label: "Border width" }
        Opt { name: "decoration:active_opacity"; label: "Focused window opacity" }
        Opt { name: "decoration:inactive_opacity"; label: "Unfocused window opacity" }
        Opt { name: "decoration:dim_inactive"; label: "Dim unfocused windows" }
        Opt { name: "decoration:dim_strength"; label: "Dim strength" }
    }

    // ── blur ──
    Group {
        title: "Blur"
        hint: "Behind translucent windows and the shell's layers"
        Opt { name: "decoration:blur:enabled"; label: "Blur" }
        Opt { name: "decoration:blur:size"; label: "Radius" }
        Opt { name: "decoration:blur:passes"; label: "Passes"; hint: "More passes blur further at a cost; 1–3 is plenty" }
    }
    Group {
        title: "Blur (advanced)"
        advanced: true
        Opt { name: "decoration:blur:vibrancy" }
        Opt { name: "decoration:blur:noise" }
        Opt { name: "decoration:blur:contrast" }
        Opt { name: "decoration:blur:brightness" }
        Opt { name: "decoration:blur:xray"; label: "X-ray"; hint: "Blur only the wallpaper, not the windows behind a translucent one" }
        Opt { name: "decoration:blur:popups"; label: "Blur popups"; hint: "Menus and tooltips too" }
    }

    // ── shadow ──
    Group {
        title: "Shadow"
        Opt { name: "decoration:shadow:enabled"; label: "Shadows" }
        Opt { name: "decoration:shadow:range"; label: "Size" }
        Opt { name: "decoration:shadow:render_power"; label: "Falloff"; hint: "How fast the shadow fades out; 1 is soft, 4 is tight" }
        Opt { name: "decoration:shadow:sharp"; label: "Sharp"; hint: "A hard-edged shadow instead of a blurred one" }
    }

    // ── animations ──
    Group {
        title: "Animations"
        hint: "The curves and speeds live in conf/look.lua"
        Opt { name: "animations:enabled"; label: "Animations" }
        Opt { name: "animations:workspace_wraparound"; label: "Workspace wrap-around"; hint: "Animate from the last workspace to the first as a step forward, not a jump back" }
        Opt { name: "misc:animate_manual_resizes"; label: "Animate manual resizes" }
        Opt { name: "misc:animate_mouse_windowdragging"; label: "Animate windows while dragging" }
    }

    // ── rendering ──
    Group {
        title: "Rendering"
        advanced: true
        Opt { name: "render:new_render_scheduling" }
        Opt { name: "render:direct_scanout" }
        Opt { name: "misc:disable_hyprland_logo"; label: "No Hyprland logo"; hint: "Never draw the logo on an empty workspace; the wallpaper daemon covers it anyway" }
        Opt { name: "misc:disable_splash_rendering"; label: "No splash text" }
        Opt { name: "misc:background_color"; label: "Background colour"; hint: "What shows before the wallpaper daemon has drawn; conf/look.lua sets the palette's surface" }
        Opt { name: "decoration:fullscreen_opacity"; label: "Fullscreen window opacity" }
        Opt { name: "decoration:dim_special"; label: "Dim behind the scratchpad" }
    }
}
