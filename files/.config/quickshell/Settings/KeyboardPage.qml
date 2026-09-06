import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Keyboard: the XKB layouts and how to switch them, key repeat, the special
// keys, and what Hyprland knows about each keyboard.
//   Layouts       one row per layout in input:kb_layout with its variant
//                 (input:kb_variant, kept aligned), a picker to add one, and
//                 the grp: switch key from input:kb_options
//   Typing        repeat rate and delay, Num Lock at start
//   Special keys  compose: and caps: tokens in input:kb_options
//   Shortcuts     a jump to the Keybinds page
//   Keyboards     what Hyprland sees, with the keymap each one has
//   Advanced      model, rules, resolve_binds_by_sym, the console keymap
// Layout and variant codes come from `localectl list-x11-keymap-*`; a layout
// is written with its variant in one hl.config call so the lists never
// disagree. Only the token a picker owns is replaced in kb_options; anything
// else there stays.
PageBody {
    id: root
    title: "Keyboard"
    subtitle: "Layouts, typing and lock keys"
    status: Hypr.schemaLoaded ? "" : "reading options…"
    Component.onCompleted: { Hypr.loadSchema(false); Hypr.refreshDevices(); load() }
    function report(err) { root.status = err || ""; root.statusError = !!err }

    // ── layouts ──
    readonly property var layoutNames: ({
        us: "English (US)", gb: "English (UK)", ie: "Irish", au: "English (Australia)", nz: "English (New Zealand)", za: "English (South Africa)",
        de: "German", at: "German (Austria)", ch: "Swiss", fr: "French", be: "Belgian", nl: "Dutch", lu: "Luxembourgish",
        es: "Spanish", latam: "Latin American", pt: "Portuguese", br: "Portuguese (Brazil)", it: "Italian", mt: "Maltese",
        pl: "Polish", cz: "Czech", sk: "Slovak", hu: "Hungarian", ro: "Romanian", si: "Slovenian", hr: "Croatian", rs: "Serbian",
        ba: "Bosnian", me: "Montenegrin", mk: "Macedonian", bg: "Bulgarian", al: "Albanian", gr: "Greek", tr: "Turkish",
        se: "Swedish", no: "Norwegian", dk: "Danish", fi: "Finnish", is: "Icelandic", fo: "Faroese",
        ru: "Russian", ua: "Ukrainian", by: "Belarusian", lt: "Lithuanian", lv: "Latvian", ee: "Estonian", md: "Moldavian",
        ge: "Georgian", am: "Armenian", az: "Azerbaijani", kz: "Kazakh", kg: "Kyrgyz", uz: "Uzbek", tj: "Tajik", tm: "Turkmen", mn: "Mongolian",
        jp: "Japanese", kr: "Korean", cn: "Chinese", tw: "Taiwanese", vn: "Vietnamese", th: "Thai", la: "Lao", kh: "Khmer", mm: "Burmese",
        "in": "Indian", pk: "Pakistani (Urdu)", bd: "Bangla", lk: "Sinhala", np: "Nepali", bt: "Dzongkha", mv: "Dhivehi",
        ir: "Persian", iq: "Iraqi", sy: "Syrian", il: "Hebrew", ara: "Arabic", eg: "Arabic (Egypt)", ma: "Arabic (Morocco)", dz: "Algerian",
        af: "Afghani", et: "Amharic", ke: "Swahili (Kenya)", tz: "Swahili (Tanzania)", ng: "Nigerian", gh: "Ghanaian", sn: "Wolof",
        ml: "Bambara", tg: "Togolese", cm: "Cameroonian", cd: "Congolese", gn: "Guinean", bw: "Tswana", ca: "Canadian",
        id: "Indonesian", my: "Malay", ph: "Filipino", epo: "Esperanto", brai: "Braille", custom: "Custom"
    })
    function layoutName(code) { return layoutNames[code] ?? code }
    property var allLayouts: []            // codes from `localectl list-x11-keymap-layouts`
    property var variants: ({})            // layout code -> [variant codes], fetched as layouts appear
    property string vcKeymap: ""

    readonly property string kbLayout: String(Hypr.optionValue("input:kb_layout", "us"))
    readonly property string kbVariant: String(Hypr.optionValue("input:kb_variant", ""))
    readonly property string kbOptions: String(Hypr.optionValue("input:kb_options", ""))
    readonly property var layouts: kbLayout.split(",").map(s => s.trim()).filter(s => s.length > 0)
    readonly property var layoutVariants: { const v = kbVariant.split(",").map(s => s.trim()); return layouts.map((l, i) => v[i] ?? "") }
    readonly property var layoutRows: layouts.map((code, i) => ({ code: code, variant: layoutVariants[i], index: i }))
    readonly property var addChoices: allLayouts.filter(c => layouts.indexOf(c) < 0)
        .map(c => ({ text: layoutName(c), value: c, hint: layoutName(c) === c ? "" : c }))
        .sort((a, b) => a.text.localeCompare(b.text))
    onLayoutsChanged: { for (const l of layouts) ensureVariants(l) }

    function ensureVariants(code) {
        if (variants[code] !== undefined) return
        const pending = Object.assign({}, variants); pending[code] = []; variants = pending
        Proc.run(["localectl", "list-x11-keymap-variants", code, "--no-pager"], (c, out) => {
            const n = Object.assign({}, root.variants)
            n[code] = out.split("\n").map(s => s.trim()).filter(s => s.length > 0)
            root.variants = n
        })
    }
    function variantChoices(code) { return [{ text: "Default", value: "" }].concat((variants[code] ?? []).map(v => ({ text: v, value: v }))) }
    function writeLayouts(ls, vs) {
        const vstr = vs.every(v => v === "") ? "" : vs.join(",")
        Hypr.setOptions({ "input:kb_layout": ls.join(","), "input:kb_variant": vstr }, err => {
            root.report(err)
            if (!err) { Hypr.refreshCurrent(["input:kb_layout", "input:kb_variant"]); Hypr.refreshDevices() }
        })
    }
    function setVariant(i, v) { const vs = layoutVariants.slice(); vs[i] = v; writeLayouts(layouts, vs) }
    function removeLayout(i) {
        if (layouts.length <= 1) return
        const ls = layouts.slice(), vs = layoutVariants.slice()
        ls.splice(i, 1); vs.splice(i, 1)
        writeLayouts(ls, vs)
    }
    function addLayout(code) { writeLayouts(layouts.concat([code]), layoutVariants.concat([""])) }

    // ── kb_options tokens ("grp:alt_shift_toggle,compose:ralt") by prefix ──
    readonly property var kbTokens: kbOptions.split(",").map(s => s.trim()).filter(s => s.length > 0)
    function tokenFor(prefix) { return kbTokens.find(t => t.indexOf(prefix + ":") === 0) ?? "" }
    function setToken(prefix, value) {
        const rest = kbTokens.filter(t => t.indexOf(prefix + ":") !== 0)
        if (value) rest.push(value)
        Hypr.setOption("input:kb_options", rest.join(","), err => {
            root.report(err)
            if (!err) { Hypr.refreshCurrent(["input:kb_options"]); Hypr.refreshDevices() }
        })
    }
    // the known choices, plus whatever unknown token is set right now
    function tokenChoices(prefix, base) {
        const cur = tokenFor(prefix)
        return base.some(c => c.value === cur) ? base : base.concat([{ text: "Custom", value: cur, hint: cur }])
    }
    readonly property var switchChoices: [
        { text: "None", value: "", hint: "the first layout only, or a keybind" },
        { text: "Alt+Shift", value: "grp:alt_shift_toggle" },
        { text: "Super+Space", value: "grp:win_space_toggle" },
        { text: "Ctrl+Shift", value: "grp:ctrl_shift_toggle" },
        { text: "Caps Lock", value: "grp:caps_toggle" },
        { text: "Alt+Space", value: "grp:alt_space_toggle" }
    ]
    readonly property var composeChoices: [
        { text: "None", value: "" },
        { text: "Right Alt", value: "compose:ralt" },
        { text: "Menu", value: "compose:menu" },
        { text: "Right Ctrl", value: "compose:rctrl" },
        { text: "Caps Lock", value: "compose:caps" }
    ]
    readonly property var capsChoices: [
        { text: "Default", value: "", hint: "Caps Lock" },
        { text: "Escape", value: "caps:escape" },
        { text: "Ctrl", value: "caps:ctrl_modifier" },
        { text: "Swap with Escape", value: "caps:swapescape" },
        { text: "None", value: "caps:none", hint: "the key does nothing" }
    ]

    // ── keyboards Hyprland sees, minus the buttons that only pretend to be one ──
    readonly property var keyboards: Hypr.devices.keyboards.filter(k => k.main === true || !/consumer-control|video-bus|power-button|wmi-hotkeys|microphone/.test(k.name))

    function load() {
        Proc.run(["localectl", "list-x11-keymap-layouts", "--no-pager"], (code, out) => {
            root.allLayouts = out.split("\n").map(s => s.trim()).filter(s => s.length > 0)
        })
        Proc.run(["localectl", "status", "--no-pager"], (code, out) => {
            const km = /VC Keymap:\s*(\S+)/.exec(out)
            root.vcKeymap = km ? km[1] : ""
        })
    }

    Group {
        title: "Layouts"
        hint: "The first one is active at start; the switch key cycles through the rest"
        Repeater {
            model: root.layoutRows
            SettingRow {
                required property var modelData
                label: root.layoutName(modelData.code)
                hint: modelData.code + (modelData.index === 0 && root.layouts.length > 1 ? " · active at start" : "")
                keywords: "layout xkb " + modelData.code
                Picker {
                    model: root.variantChoices(modelData.code)
                    current: modelData.variant
                    minWidth: 170
                    onPicked: v => root.setVariant(modelData.index, v)
                }
                IconButton { glyph: "󰆴"; kind: "danger"; small: true; visible: root.layouts.length > 1; onClicked: root.removeLayout(modelData.index) }
            }
        }
        SettingRow {
            label: "Add layout"
            hint: "Appended to the list; its variant can be picked above once it is in"
            keywords: "add layout language xkb new"
            Picker {
                model: root.addChoices
                current: undefined
                placeholder: root.allLayouts.length ? "Choose a layout…" : "reading…"
                searchable: true
                minWidth: 220
                onPicked: v => root.addLayout(v)
            }
        }
        SettingRow {
            label: "Switch layouts with"
            hint: "The key combination that goes to the next layout (grp: option)"
            keywords: "switch toggle layout key combination grp alt shift super space caps"
            Picker { model: root.tokenChoices("grp", root.switchChoices); current: root.tokenFor("grp"); minWidth: 170; onPicked: v => root.setToken("grp", v) }
        }
    }

    Group {
        title: "Typing"
        OptionRow { name: "input:repeat_rate"; label: "Repeat rate"; hint: "Repeats per second while a key is held" }
        OptionRow { name: "input:repeat_delay"; label: "Repeat delay"; hint: "Milliseconds a key is held before it repeats" }
        OptionRow { name: "input:numlock_by_default"; label: "Num Lock on at start" }
    }

    Group {
        title: "Special keys"
        hint: "XKB options for Compose and Caps Lock; other kb_options stay as they are"
        SettingRow {
            label: "Compose key"
            hint: "Held then two keys typed gives an accented or special character"
            keywords: "compose accents special characters ralt menu rctrl"
            Picker { model: root.tokenChoices("compose", root.composeChoices); current: root.tokenFor("compose"); minWidth: 170; onPicked: v => root.setToken("compose", v) }
        }
        SettingRow {
            label: "Caps Lock behaviour"
            hint: "What the Caps Lock key does"
            keywords: "caps lock escape ctrl control swap disable"
            Picker { model: root.tokenChoices("caps", root.capsChoices); current: root.tokenFor("caps"); minWidth: 170; onPicked: v => root.setToken("caps", v) }
        }
    }

    Group {
        title: "Shortcuts"
        SettingRow {
            label: "Keyboard shortcuts"
            hint: "Every action and the keys bound to it"
            keywords: "keybinds shortcuts hotkeys bindings"
            clickable: true
            onClicked: Overlays.openSettings("keybinds")
        }
    }

    Group {
        title: "Keyboards"
        hint: "As Hyprland sees them, with the keymap each one has right now"
        advanced: true
        SettingRow { visible: hit && root.keyboards.length === 0; label: "No keyboards"; hint: "Hyprland has not reported any"; keywords: "keyboard device" }
        Repeater {
            model: root.keyboards
            SettingRow {
                required property var modelData
                label: Hypr.prettyDevice(modelData.name)
                hint: modelData.name + (modelData.main === true ? " · main keyboard" : "")
                keywords: "keyboard device " + modelData.name
                value: (modelData.active_keymap || "") + (modelData.capsLock ? "  ·  Caps Lock" : "") + (modelData.numLock ? "  ·  Num Lock" : "")
            }
        }
    }

    Group {
        title: "Advanced"
        hint: "XKB details most keyboards never need"
        advanced: true
        OptionRow { name: "input:kb_model"; label: "Model"; hint: "XKB model, such as pc105; blank for the default" }
        OptionRow { name: "input:kb_rules"; label: "Rules"; hint: "XKB rules file; blank for evdev" }
        OptionRow { name: "input:resolve_binds_by_sym"; label: "Binds follow the layout"; hint: "Keybinds match the symbol the current layout produces rather than the key's position" }
        SettingRow {
            label: "Console keymap"
            hint: "The layout of the text consoles (Ctrl+Alt+F-keys), from vconsole.conf"
            keywords: "vconsole tty console keymap"
            value: root.vcKeymap.length > 0 ? root.vcKeymap : "not set"
        }
    }
}
