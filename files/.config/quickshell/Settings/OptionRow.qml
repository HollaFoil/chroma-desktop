import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services

// One Hyprland option as a SettingRow, typed from `hyprctl descriptions`:
//     Pretty name  ●  ↺                    [toggle | pills | ──●── 12 | entry]
//     description in small dim text
// bool -> toggle, int with a map -> pills, numbers with a range -> slider,
// css gaps ("5 5 5 5") -> one slider for all four sides, other strings ->
// entry (or a picker when the description lists the choices). Colours and
// lists are read-only: the palette owns the colours.
// A change is applied live and written to state/settings.json; the dot marks
// an override, ↺ removes it and reloads so the conf/*.lua value comes back.
// `label` and `hint` may be given to replace the generated ones.
SettingRow {
    id: root
    required property string name
    readonly property var entry: Hypr.schema[name] ?? ({ name: name, description: "(unknown option)", default: "" })
    readonly property var cur: entry.current
    readonly property string kind: kindOf(entry)
    readonly property bool overridden: Hypr.isOverridden(name)
    property string status: ""
    property bool statusError: false

    label: pretty(name)
    hint: sentence(entry.description || "")
    keywords: name.replace(/[:_.]/g, " ") + " " + name
    // an option this Hyprland does not know is left out rather than shown broken
    visible: hit && (!Hypr.schemaLoaded || Hypr.schema[name] !== undefined)
    Component.onCompleted: Hypr.loadSchema(false)

    function kindOf(e) {
        const d = e.default, vt = e.vtype
        if (e.map && e.map.length) return "enum"
        if (/(^|[:._])col(or)?([._]|$)/.test(e.name) || vt === "gradient" || (typeof d === "string" && /^[0-9a-fA-F]{8}( .*)?$/.test(d))) return "color"
        if (vt === "bool" || (vt === undefined && typeof d === "boolean")) return "bool"
        if (vt === "float" || (vt === undefined && typeof d === "number" && !Number.isInteger(d))) return (e.min === 0 && e.max === 1) ? "percent" : "float"
        if (vt === "int" || (vt === undefined && Number.isInteger(d))) return "int"
        if (vt === "css" || (typeof d === "string" && /^\s*-?\d+(\s+-?\d+){0,3}\s*$/.test(d) && e.name.indexOf("gap") >= 0)) return "gap"
        if (vt === "str" || typeof d === "string") return strChoices(e).length ? "choice" : "str"
        return "list"
    }
    function sentence(t) { return t ? t.charAt(0).toUpperCase() + t.slice(1) : t }
    function pretty(n) { const parts = n.split(":"); return sentence((parts.length > 1 ? parts.slice(1) : parts).join(" ").replace(/_/g, " ").replace(/\./g, " ")) }
    function enumOptions(e) {
        const pairs = []
        for (const item of (e.map || [])) for (const k in item) pairs.push({ text: sentence(k.replace(/_/g, " ")), value: item[k] })
        return pairs.sort((a, b) => a.value - b.value)
    }
    function strChoices(e) {
        const m = /\[([a-z0-9_]+(?:\/[a-z0-9_]+)+)(?:\/[^\]]*)?\]/.exec(e.description || "")
        return m ? m[1].split("/") : []
    }
    function gapValue(t) { const v = parseInt(String(t).split(/\s+/)[0]); return isNaN(v) ? 0 : v }
    readonly property var range: {
        let lo = entry.min, hi = entry.max, step
        const fallback = { int: [0, 100, 1], float: [0, 1, 0.01], gap: [0, 60, 1] }
        if (lo === undefined || hi === undefined || hi <= lo) { const f = fallback[kind] || [0, 100, 1]; lo = f[0]; hi = f[1]; step = f[2] }
        else step = kind === "float" ? Math.max(Math.round((hi - lo) / 100 * 100) / 100, 0.01) : 1
        return { lo, hi, step }
    }
    readonly property real sliderValue: kind === "percent" ? Math.round((cur || 0) * 100) : kind === "gap" ? gapValue(cur) : (Number(cur) || 0)
    readonly property string readonlyText: kind === "color"
        ? (typeof cur === "number" ? "#" + (cur & 0xFFFFFF).toString(16).padStart(6, "0") : String(cur)) + "  (from the palette)"
        : String(cur)
    readonly property var choiceItems: kind === "enum" ? enumOptions(entry) : kind === "choice" ? strChoices(entry).map(c => ({ text: sentence(c.replace(/_/g, " ")), value: c })) : []

    function set(value) {
        if (kind === "int" || kind === "gap" || kind === "enum") value = Math.round(Number(value))
        else if (kind === "percent") value = Math.round(value) / 100
        else if (kind === "float") value = Number(value)
        Hypr.setOption(name, value, err => {
            status = err || ""; statusError = !!err
            if (!err) Hypr.refreshCurrent([name])
        })
    }
    function reset() { Hypr.resetOption(name); status = ""; resetRefresh.restart() }
    Timer { id: resetRefresh; interval: 600; onTriggered: Hypr.refreshCurrent([root.name]) }

    afterLabel: [
        Glyph { text: "●"; size: 8; color: Colors.tertiary; visible: root.overridden },
        IconButton { glyph: "󰦛"; kind: "action"; small: true; visible: root.overridden; implicitWidth: 22; onClicked: root.reset() }
    ]
    value: (kind === "color" || kind === "list") ? readonlyText : ""

    Toggle { visible: root.kind === "bool"; checked: !!root.cur; onToggled: v => root.set(v) }
    Segmented {
        visible: (root.kind === "enum" || root.kind === "choice") && root.choiceItems.length <= 4
        model: root.choiceItems.map(o => o.text)
        current: root.choiceItems.findIndex(o => o.value === root.cur)
        onPicked: i => root.set(root.choiceItems[i].value)
    }
    Picker {
        visible: (root.kind === "enum" || root.kind === "choice") && root.choiceItems.length > 4
        model: root.choiceItems
        current: root.cur
        onPicked: v => root.set(v)
    }
    Slider {
        id: sl
        visible: root.kind === "percent" || root.kind === "int" || root.kind === "float" || root.kind === "gap"
        minWidth: 190
        from: root.kind === "percent" ? 0 : root.range.lo
        to: root.kind === "percent" ? 100 : root.range.hi
        step: root.kind === "percent" ? 1 : root.range.step
        value: root.sliderValue
        onMoved: v => root.set(v)
    }
    Label {
        visible: sl.visible
        text: root.kind === "percent" ? Math.round(sl._live) + "%" : root.kind === "float" ? sl._live.toFixed(2) : String(Math.round(sl._live))
        size: Tokens.fontSizeSmall; dim: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 44
    }
    Entry {
        visible: root.kind === "str"
        Layout.preferredWidth: 200
        text: String(root.cur ?? "")
        onEditingFinished: if (text !== String(root.cur ?? "")) root.set(text)
    }
    StatusLine { visible: root.status.length > 0; text: root.status; error: root.statusError; Layout.maximumWidth: 260 }
}
