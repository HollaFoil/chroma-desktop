import QtQuick
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// Time, slanted into the top-right corner. Click flips to the date, right
// click opens the calendar. The format follows Prefs (clock.24h,
// clock.seconds; clock.date starts it on the date), set on Date & Time.
Bubble {
    id: root
    corners: "clock"
    fullHeight: true
    padL: 25; padR: 12
    marginL: 7
    property bool showDate: Prefs.get("clock.date", false)
    readonly property bool h24: Prefs.get("clock.24h", true)
    readonly property bool seconds: Prefs.get("clock.seconds", true)
    readonly property string timeFormat: (h24 ? "HH:mm" : "h:mm") + (seconds ? ":ss" : "") + (h24 ? "" : " AP")
    SystemClock { id: clock; precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes }
    onClicked: showDate = !showDate
    onRightClicked: openPopup("calendar", "right")
    Label {
        text: root.showDate ? "󰃭 " + Qt.formatDateTime(clock.date, "ddd dd MMM yyyy") : "󰥔 " + Qt.formatDateTime(clock.date, root.timeFormat)
        size: Tokens.fontSizeTitle
        topPadding: 2
    }
}
