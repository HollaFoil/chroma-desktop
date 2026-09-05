import QtQuick
import qs.Theme

// One quiet line under a section: what just happened, or what went wrong.
// Collapses when empty.
Label {
    property bool error: false
    visible: text.length > 0
    size: Tokens.fontSizeSmall
    color: error ? Colors.error : Colors.surfaceVariantFg
    wrapMode: Text.Wrap
    leftPadding: 4
    rightPadding: 4
}
