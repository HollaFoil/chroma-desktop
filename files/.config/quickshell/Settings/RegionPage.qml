import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// Region & Language: the system locale (/etc/locale.conf) as localectl sees it.
//   Language   display language (LANG)
//   Formats    one locale for every LC_* category, with a preview of a date, a
//              number and an amount of money in it
//   Keyboard   console keymap (read-only) and a jump to the Keyboard page
//   Advanced   one picker per LC_* category
// Backed by `localectl status` (System Locale: LANG=… LC_TIME=…, VC Keymap),
// `localectl list-locales` for the installed choices, and `localectl set-locale
// LANG=… LC_TIME=… …` with every variable passed at once, since set-locale
// replaces the whole file. A change is for the next login; nothing running
// re-reads its locale.
PageBody {
    id: root
    title: "Region & Language"
    subtitle: "Language and formats; applies at the next login"
    status: "reading…"

    readonly property var categories: ["LC_TIME", "LC_NUMERIC", "LC_MONETARY", "LC_MEASUREMENT", "LC_PAPER", "LC_NAME", "LC_ADDRESS", "LC_TELEPHONE", "LC_IDENTIFICATION"]
    readonly property var categoryNames: ({
        LC_TIME: ["Dates and times", "Calendar, weekday names, clock"],
        LC_NUMERIC: ["Numbers", "Decimal mark and digit grouping"],
        LC_MONETARY: ["Currency", "Symbol and how amounts are written"],
        LC_MEASUREMENT: ["Measurement", "Metric or US units"],
        LC_PAPER: ["Paper size", "A4 or Letter"],
        LC_NAME: ["Names", "How people are addressed"],
        LC_ADDRESS: ["Addresses", "Postal address layout, country codes"],
        LC_TELEPHONE: ["Telephone", "Phone number formats"],
        LC_IDENTIFICATION: ["Identification", "Metadata about the locale itself"]
    })
    property var vars: ({})          // LANG, LC_* -> locale code, as set right now
    property var installed: []       // codes from `localectl list-locales`
    property string vcKeymap: ""
    property string preview: ""      // "date · number · money" for the formats locale
    readonly property string lang: vars.LANG || ""
    // the one locale every category agrees on, "" when unset, "@mixed" when they differ
    readonly property string formats: {
        const vals = categories.map(c => vars[c] || vars.LANG || "")
        const first = vals[0]
        return vals.every(v => v === first) ? first : "@mixed"
    }
    readonly property var choices: installed.map(c => ({ text: friendly(c), value: c, hint: friendly(c) === c ? "" : c }))
    readonly property var formatChoices: formats === "@mixed" ? [{ text: "Mixed", value: "@mixed", hint: "categories differ; see Advanced" }].concat(choices) : choices

    readonly property var names: ({
        C: "POSIX (C)", POSIX: "POSIX",
        en_US: "English (United States)", en_GB: "English (United Kingdom)", en_AU: "English (Australia)", en_CA: "English (Canada)",
        en_IE: "English (Ireland)", en_NZ: "English (New Zealand)", en_IN: "English (India)", en_ZA: "English (South Africa)", en_DK: "English (Denmark)",
        nl_NL: "Dutch (Netherlands)", nl_BE: "Dutch (Belgium)",
        de_DE: "German (Germany)", de_AT: "German (Austria)", de_CH: "German (Switzerland)",
        fr_FR: "French (France)", fr_BE: "French (Belgium)", fr_CA: "French (Canada)", fr_CH: "French (Switzerland)",
        es_ES: "Spanish (Spain)", es_MX: "Spanish (Mexico)", es_AR: "Spanish (Argentina)",
        it_IT: "Italian (Italy)", pt_PT: "Portuguese (Portugal)", pt_BR: "Portuguese (Brazil)",
        lt_LT: "Lithuanian (Lithuania)", lv_LV: "Latvian (Latvia)", et_EE: "Estonian (Estonia)",
        pl_PL: "Polish (Poland)", cs_CZ: "Czech (Czechia)", sk_SK: "Slovak (Slovakia)", hu_HU: "Hungarian (Hungary)",
        ro_RO: "Romanian (Romania)", bg_BG: "Bulgarian (Bulgaria)", el_GR: "Greek (Greece)", tr_TR: "Turkish (Türkiye)",
        ru_RU: "Russian (Russia)", uk_UA: "Ukrainian (Ukraine)",
        sv_SE: "Swedish (Sweden)", da_DK: "Danish (Denmark)", nb_NO: "Norwegian Bokmål (Norway)", nn_NO: "Norwegian Nynorsk (Norway)", fi_FI: "Finnish (Finland)", is_IS: "Icelandic (Iceland)",
        ja_JP: "Japanese (Japan)", ko_KR: "Korean (Korea)", zh_CN: "Chinese (China)", zh_TW: "Chinese (Taiwan)", zh_HK: "Chinese (Hong Kong)",
        ar_SA: "Arabic (Saudi Arabia)", ar_EG: "Arabic (Egypt)", he_IL: "Hebrew (Israel)", hi_IN: "Hindi (India)", th_TH: "Thai (Thailand)", vi_VN: "Vietnamese (Vietnam)", id_ID: "Indonesian (Indonesia)"
    })
    function friendly(code) {
        const base = code.split(".")[0].split("@")[0]
        const n = names[base]
        if (!n) return code
        const mod = code.indexOf("@") >= 0 ? " @" + code.split("@")[1] : ""
        return n + mod
    }

    function load() {
        Proc.run(["localectl", "list-locales", "--no-pager"], (code, out) => {
            root.installed = out.split("\n").map(s => s.trim()).filter(s => s.length > 0)
        })
        Proc.run(["localectl", "status", "--no-pager"], (code, out, err) => {
            if (code !== 0) { root.status = "localectl: " + (err.trim() || "exit " + code); root.statusError = true; return }
            const v = {}
            const re = /\b(LANG|LC_[A-Z]+)=(\S+)/g
            let m
            while ((m = re.exec(out)) !== null) v[m[1]] = m[2]
            root.vars = v
            const km = /VC Keymap:\s*(\S+)/.exec(out)
            root.vcKeymap = km ? km[1] : ""
            if (root.status === "reading…") root.status = ""
            root.updatePreview()
        })
    }
    // a date, a number and an amount of money as the formats locale writes them
    function updatePreview() {
        const loc = formats === "@mixed" ? (vars.LC_TIME || lang) : formats
        if (!loc) { preview = ""; return }
        // /usr/bin/printf, not the shell's: coreutils parses the number in C and
        // prints it in the locale, the builtin would reject "1234567.891" under a
        // decimal-comma locale
        const script = "export LC_ALL=\"$QS_LOC\"; date '+%A %-d %B %Y, %H:%M'; echo @@; /usr/bin/printf \"%'.2f\" 1234567.891; echo @@; locale -k currency_symbol p_cs_precedes mon_decimal_point mon_thousands_sep"
        Proc.run(["sh", "-c", script], (code, out, err) => {
            if (code !== 0 || err.indexOf("setlocale") >= 0 || err.indexOf("cannot change locale") >= 0) { root.preview = ""; return }
            const p = out.split("@@").map(s => s.trim())
            const kv = {}
            for (const line of (p[2] || "").split("\n")) { const i = line.indexOf("="); if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1).replace(/^"|"$/g, "") }
            const sym = kv.currency_symbol || ""
            const amount = "1" + (kv.mon_thousands_sep || "") + "234" + (kv.mon_decimal_point || ".") + "56"
            const money = sym ? (kv.p_cs_precedes === "0" ? amount + " " + sym : sym + " " + amount) : ""
            root.preview = [p[0], p[1], money].filter(s => s && s.length > 0).join("   ·   ")
        }, { QS_LOC: loc })
    }
    // write the whole set at once: set-locale replaces /etc/locale.conf
    function applyVars(next) {
        const args = ["set-locale"]
        for (const k of ["LANG"].concat(categories)) if (next[k]) args.push(k + "=" + next[k])
        root.statusError = false
        root.status = "applying…"
        Proc.run(["localectl"].concat(args), (code, out, err) => {
            if (code !== 0) { root.status = err.trim() || out.trim() || "localectl failed (exit " + code + ")"; root.statusError = true }
            else root.status = "saved; takes effect at the next login"
            load()
        })
    }
    function setVar(key, value) { const n = Object.assign({}, vars); n[key] = value; applyVars(n) }
    function setFormats(value) {
        if (value === "@mixed") return
        const n = Object.assign({}, vars)
        for (const c of categories) n[c] = value
        applyVars(n)
    }
    onFormatsChanged: updatePreview()
    Component.onCompleted: load()

    Group {
        title: "Language"
        hint: "Menus and messages in programs that are translated"
        SettingRow {
            label: "Display language"
            hint: "LANG; the fallback for anything not set below"
            keywords: "language locale LANG translation"
            Picker { model: root.choices; current: root.lang; minWidth: 220; placeholder: root.installed.length ? "Choose…" : "reading…"; onPicked: v => root.setVar("LANG", v) }
        }
    }

    Group {
        title: "Formats"
        hint: "Dates, numbers, money, paper and units together"
        SettingRow {
            label: "Formats"
            hint: "Sets every LC_* category to one locale"
            keywords: "formats region dates numbers currency measurement paper LC_TIME LC_NUMERIC LC_MONETARY"
            Picker { model: root.formatChoices; current: root.formats; minWidth: 220; onPicked: v => root.setFormats(v) }
        }
        SettingRow {
            visible: hit && root.preview.length > 0
            label: "Preview"
            hint: "A date, a number and an amount as they will look"
            keywords: "example preview sample"
            value: root.preview
        }
    }

    Group {
        title: "Keyboard"
        SettingRow {
            label: "Console keymap"
            hint: "The layout of the text consoles (Ctrl+Alt+F-keys), from vconsole.conf"
            keywords: "vconsole keymap tty console"
            value: root.vcKeymap.length > 0 ? root.vcKeymap : "not set"
        }
        SettingRow {
            label: "Keyboard layout"
            hint: "Layouts, variants and options for the desktop live on the Keyboard page"
            keywords: "xkb layout variant keyboard"
            clickable: true
            onClicked: Overlays.openSettings("keyboard")
        }
    }

    Group {
        title: "Advanced"
        hint: "Each category on its own; unset ones follow the display language"
        advanced: true
        Repeater {
            model: root.categories
            SettingRow {
                required property string modelData
                label: root.categoryNames[modelData][0]
                hint: root.categoryNames[modelData][1]
                keywords: modelData + " " + modelData.replace("LC_", "").toLowerCase()
                Picker {
                    model: root.choices
                    current: root.vars[modelData] || root.lang
                    minWidth: 220
                    onPicked: v => root.setVar(modelData, v)
                }
            }
        }
    }
}
