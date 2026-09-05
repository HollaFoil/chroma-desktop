import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets
import qs.Services
// wttr.in, every 20 minutes. Location from the options, or by IP when blank.
RowLayout {
    id: root
    readonly property var w: parent.widget
    readonly property string location: String(Desktop.option(w, "location") || "")
    property var cur: null
    property string area: ""
    property string error: ""
    spacing: 16
    function refresh() {
        Proc.run(["curl", "-sf", "--max-time", "15", "https://wttr.in/" + encodeURIComponent(location) + "?format=j1"], (code, out) => {
            if (code !== 0) { error = "no weather (offline?)"; return }
            try { const j = JSON.parse(out); cur = j.current_condition[0]; area = (j.nearest_area[0].areaName[0].value || ""); error = "" } catch (e) { error = "weather unreadable" }
        })
    }
    onLocationChanged: refresh()
    Timer { interval: 20 * 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    function glyph(code) {
        const c = parseInt(code)
        if (c === 113) return "󰖙"
        if (c === 116) return "󰖕"
        if (c === 119 || c === 122) return "󰖐"
        if (c === 143 || c === 248 || c === 260) return "󰖑"
        if (c >= 200 && c < 230 || c === 386 || c === 389 || c === 392 || c === 395) return "󰖓"
        if (c === 227 || c === 230 || (c >= 320 && c <= 338) || c === 368 || c === 371) return "󰖘"
        return "󰖗"
    }
    Glyph { text: root.cur ? root.glyph(root.cur.weatherCode) : "󰖕"; size: Math.min(64, parent.height * 0.5); Layout.alignment: Qt.AlignVCenter }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Label { text: root.cur ? root.cur.temp_C + "°C" : (root.error || "…"); size: root.cur ? 34 : Tokens.fontSizeSmall; font.weight: Font.Bold; dim: !root.cur }
        Label { text: root.cur ? root.cur.weatherDesc[0].value : ""; size: Tokens.fontSizeSmall; Layout.fillWidth: true }
        Label { text: root.cur ? "feels " + root.cur.FeelsLikeC + "°  ·  " + root.cur.humidity + "% humidity  ·  " + root.cur.windspeedKmph + " km/h" : ""; size: Tokens.fontSizeTiny; dim: true; regular: true; Layout.fillWidth: true; wrapMode: Text.Wrap }
        Label { text: root.area; size: Tokens.fontSizeTiny; dim: true; visible: root.area.length > 0 }
    }
}
