import QtQuick
import qs.Theme

// Body text. Bold by default (the shell's voice); regular for descriptions.
Text {
    property bool dim: false
    property bool regular: false
    property int size: Tokens.fontSize
    font.family: Tokens.fontFamily
    font.bold: !regular
    font.pixelSize: size
    color: dim ? Colors.surfaceVariantFg : Colors.surfaceFg
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
}
