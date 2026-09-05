import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Widgets

// Title (with room for a button on the right) over a scrolling body: what
// every settings page is made of.
ColumnLayout {
    id: root
    property string title: ""
    property int maxHeight: 580
    property alias headerItems: trail.data
    property alias status: statusLine.text
    property alias statusError: statusLine.error
    default property alias content: body.content
    spacing: Tokens.sp2

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Label { text: root.title; size: Tokens.fontSizeHeading; color: Colors.primary; Layout.fillWidth: true }
        RowLayout { id: trail; spacing: Tokens.sp2 }
    }
    StatusLine { id: statusLine; Layout.fillWidth: true; leftPadding: 6 }
    Scroller {
        id: body
        Layout.fillWidth: true
        maxHeight: root.maxHeight
        spacing: Tokens.sp2
    }
}
