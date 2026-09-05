import QtQuick
import qs.Theme

// A nerd-font icon. Primary by default, so a bare Glyph reads as an accent.
Text {
    property int size: Tokens.fontSizeIcon
    font.family: Tokens.fontFamily
    font.bold: true
    font.pixelSize: size
    color: Colors.primary
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    Behavior on color { ColorAnimation { duration: Tokens.durSlow } }
}
