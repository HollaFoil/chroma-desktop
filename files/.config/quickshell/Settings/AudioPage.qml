import QtQuick
import QtQuick.Layouts
import qs.Popups
PageBody {
    title: "Audio"
    subtitle: "Output and input devices, per-app routing"
    AudioPanel { Layout.fillWidth: true; Layout.leftMargin: 6; Layout.rightMargin: 8; appsOpen: true; sliderWidth: 320 }
}
