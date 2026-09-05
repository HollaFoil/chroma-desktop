import QtQuick
import QtQuick.Layouts
import qs.Theme

// Glyph, title, then whatever controls the section owns on the right.
RowLayout {
    id: root
    property string glyph: ""
    property string title: ""
    property bool inactive: false
    default property alias trailing: trail.data
    spacing: Tokens.sp2

    Glyph {
        text: root.glyph
        color: root.inactive ? Colors.onSurfaceVariant : Colors.primary
        Layout.preferredWidth: 24
    }
    Label {
        text: root.title
        size: Tokens.fontSizeTitle
        dim: root.inactive
        Layout.fillWidth: true
    }
    RowLayout { id: trail; spacing: Tokens.sp1 }
}
