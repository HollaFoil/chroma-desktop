import QtQuick
import Quickshell
import qs.Theme
import qs.Widgets

// Time, slanted into the top-right corner. Click flips to the date, right
// click opens the calendar.
Bubble {
    id: root
    corners: "clock"
    fullHeight: true
    padL: 25; padR: 12
    marginL: 7
    property bool showDate: false
    SystemClock { id: clock; precision: SystemClock.Seconds }
    onClicked: showDate = !showDate
    onRightClicked: openPopup("calendar", "right")
    Label {
        text: root.showDate ? "󰃭 " + Qt.formatDateTime(clock.date, "ddd dd MMM yyyy") : "󰥔 " + Qt.formatDateTime(clock.date, "HH:mm:ss")
        size: Tokens.fontSizeTitle
        topPadding: 2
    }
}
