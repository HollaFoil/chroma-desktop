import QtQuick
import qs.Theme
import qs.Widgets

// A small primary caption that starts a group of rows.
Label {
    property bool first: false
    size: Tokens.fontSizeSmall
    color: Colors.primary
    leftPadding: 6
    topPadding: first ? 0 : 10
}
