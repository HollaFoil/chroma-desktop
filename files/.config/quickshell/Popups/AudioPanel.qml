import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Theme
import qs.Widgets
import qs.Services

//   [speaker] ─────●──── 75%   HyperX Cloud III ▾
//   [mic]     ───●────── 60%   HyperX Cloud III ▾
//   Apps ▸   (per-stream rows: icon, name, slider, mute, device ▾)
// Device choice is an inline list under the row, never a combo box. Each app
// row's `▾` routes that stream (or the whole app, for a session or always).
ColumnLayout {
    id: root
    property bool appsOpen: Popups.extra === "showcase"   // opened via `popup show audio showcase`
    property int sliderWidth: 190
    spacing: Tokens.sp1
    Component.onCompleted: Audio.refreshPinned()

    // output
    VolumeRow {
        Layout.fillWidth: true
        node: Audio.defaultSink
        sliderWidth: root.sliderWidth
        Pill { text: Audio.shortName(Audio.defaultSink) + "  ▾"; small: true; minWidth: 110; onClicked: sinkList.open = !sinkList.open }
    }
    Revealer {
        id: sinkList
        Layout.fillWidth: true
        Layout.leftMargin: 38
        DeviceList {
            Layout.fillWidth: true
            nodes: Audio.sinks
            current: Audio.defaultSink ? Audio.defaultSink.name : null
            onPicked: name => { sinkList.open = false; const n = Audio.sinks.find(s => s.name === name); if (n) Audio.setDefaultSink(n) }
        }
    }
    // input
    VolumeRow {
        Layout.fillWidth: true
        node: Audio.defaultSource
        mic: true
        sliderWidth: root.sliderWidth
        Pill { text: Audio.shortName(Audio.defaultSource) + "  ▾"; small: true; minWidth: 110; onClicked: sourceList.open = !sourceList.open }
    }
    Revealer {
        id: sourceList
        Layout.fillWidth: true
        Layout.leftMargin: 38
        DeviceList {
            Layout.fillWidth: true
            nodes: Audio.sources
            current: Audio.defaultSource ? Audio.defaultSource.name : null
            onPicked: name => { sourceList.open = false; const n = Audio.sources.find(s => s.name === name); if (n) Audio.setDefaultSource(n) }
        }
    }
    Divider { Layout.fillWidth: true }

    // per-app streams
    ListRow {
        accent: true
        padY: 2
        onClicked: { root.appsOpen = !root.appsOpen; Audio.refreshPinned() }
        Label { text: (root.appsOpen ? "󰅀" : "󰅂") + "  Apps (" + Audio.streams.length + ")"; size: Tokens.fontSizeSmall; dim: !root.appsOpen }
    }
    Revealer {
        open: root.appsOpen
        Layout.fillWidth: true
        spacing: Tokens.sp1
        Repeater {
            model: Audio.streams
            ColumnLayout {
                id: app
                required property var modelData
                required property int index
                readonly property var stream: modelData
                readonly property var rule: Audio.ruleFor(stream)
                readonly property var sinkNow: Audio.sinkOf(stream)
                readonly property bool pinned: Audio.pinned[stream.id] === true
                property string scope: rule ? rule.scope : "stream"
                readonly property var current: rule ? rule.sink : (pinned && sinkNow && Audio.defaultSink && sinkNow.name !== Audio.defaultSink.name ? sinkNow.name : null)
                readonly property string routeText: {
                    if (rule) {
                        const dev = Audio.sinks.find(s => s.name === rule.sink)
                        return (rule.scope === "always" ? "󰐃 " : "󰔛 ") + (dev ? Audio.shortName(dev) : "(device off)")
                    }
                    if (current) { const dev = Audio.sinks.find(s => s.name === current); return dev ? Audio.shortName(dev) : current }
                    return "Default"
                }
                Layout.fillWidth: true
                spacing: 2
                VolumeRow {
                    Layout.fillWidth: true
                    node: app.stream
                    sliderWidth: Math.max(80, root.sliderWidth - 110)
                    Image {
                        source: Audio.appIcon(app.stream)
                        sourceSize.width: 16; sourceSize.height: 16
                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                        visible: status === Image.Ready
                    }
                    Label { text: Audio.appLabel(app.stream); size: Tokens.fontSizeSmall; Layout.preferredWidth: 96; Layout.maximumWidth: 96 }
                    Pill { text: app.routeText + "  ▾"; small: true; minWidth: 90; onClicked: route.open = !route.open }
                }
                Revealer {
                    id: route
                    open: app.index === 0 && Popups.extra === "showcase"
                    Layout.fillWidth: true
                    Layout.leftMargin: 38
                    spacing: 4
                    Segmented {
                        model: ["This stream", "This app, until logout", "This app, always"]
                        current: ["stream", "session", "always"].indexOf(app.scope)
                        onPicked: i => app.scope = ["stream", "session", "always"][i]
                    }
                    DeviceList {
                        Layout.fillWidth: true
                        nodes: Audio.sinks
                        current: app.current
                        extraFirst: "Default (follows the output above)"
                        onPicked: name => { route.open = false; Audio.route(app.stream, name, app.scope) }
                    }
                }
            }
        }
        Label { visible: Audio.streams.length === 0; text: "nothing is playing"; dim: true; regular: true; size: Tokens.fontSizeSmall; leftPadding: 6 }
    }
}
