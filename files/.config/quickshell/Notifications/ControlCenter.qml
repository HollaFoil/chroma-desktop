import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Theme
import qs.Widgets
import qs.Services

// The notification centre: title and clear-all, do-not-disturb, a row of
// quick buttons, the output volume, what is playing, then the notifications
// grouped by app. Top-right under the bar on the focused screen.
OverlayWindow {
    id: win
    placement: "bar"
    side: "right"
    anchorRight: 18
    property bool isOpen: false
    property var allowedScreens: Quickshell.screens
    property var expanded: ({})
    open: isOpen
    onDismissed: isOpen = false
    function show() {
        const focused = Hyprland.focusedMonitor
        const s = allowedScreens.find(sc => focused && sc.name === focused.name) ?? allowedScreens[0]
        if (s) screen = s
        isOpen = true
    }
    function toggle() { if (isOpen) isOpen = false; else show() }

    readonly property var groups: {
        const byApp = {}, order = []
        for (const e of Notifs.items) { if (!byApp[e.app]) { byApp[e.app] = []; order.push(e.app) } byApp[e.app].push(e) }
        return order.map(a => ({ app: a, entries: byApp[a] }))
    }
    readonly property var player: Media.player ?? (Mpris.players.values.find(p => p.trackTitle) ?? null)
    readonly property var sink: Audio.defaultSink
    readonly property var source: Audio.defaultSource

    Card {
        slanted: false
        padX: 12; padY: 12
        spacing: 10
        Item {
            Layout.preferredWidth: 396
            Layout.preferredHeight: 576
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Notifications"; size: Tokens.fontSizeHeading; Layout.fillWidth: true; leftPadding: 4 }
                    Pill { text: "󰎟  Clear"; small: true; enabled: Notifs.count > 0; onClicked: Notifs.clearAll() }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Tokens.rLg
                    color: Colors.surfaceContainerHighest
                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                        Label { text: "Do not disturb"; Layout.fillWidth: true }
                        Toggle { checked: Notifs.dnd; onToggled: v => Notifs.dnd = v }
                    }
                }
                // quick buttons: mute output · mute input · screenshot · lock · power off
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Tokens.rMd
                    color: Colors.surfaceContainerHighest
                    RowLayout {
                        anchors { fill: parent; margins: 6 }
                        spacing: 6
                        Repeater {
                            model: [
                                { glyph: "󰝟", on: win.sink && win.sink.audio ? win.sink.audio.muted : false, run: () => Audio.toggleMute(win.sink) },
                                { glyph: "󰍭", on: win.source && win.source.audio ? win.source.audio.muted : false, run: () => Audio.toggleMute(win.source) },
                                { glyph: "󰹑", on: false, run: () => { win.isOpen = false; Proc.detach('grim -g "$(slurp)" - | wl-copy') } },
                                { glyph: "󰌾", on: false, run: () => { win.isOpen = false; Lock.lock() } },
                                { glyph: "󰐥", on: false, danger: true, run: () => Proc.detach("systemctl poweroff") }
                            ]
                            Rectangle {
                                id: qb
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Tokens.rXs
                                color: modelData.on ? Colors.primary : qma.containsMouse ? Tokens.alpha(modelData.danger ? Colors.error : Colors.primary, Tokens.aHover) : Colors.surfaceContainerHigh
                                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                                Glyph { anchors.centerIn: parent; text: qb.modelData.glyph; size: 18
                                    color: qb.modelData.on ? Colors.primaryFg : qb.modelData.danger && qma.containsMouse ? Colors.error : Colors.surfaceFg }
                                MouseArea { id: qma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: qb.modelData.run() }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4; Layout.rightMargin: 4
                    spacing: 10
                    Glyph { text: Audio.speakerIcon(Audio.pct(win.sink), win.sink && win.sink.audio && win.sink.audio.muted); size: 16; color: Colors.surfaceFg }
                    Slider { Layout.fillWidth: true; value: Math.min(1, win.sink && win.sink.audio ? win.sink.audio.volume : 0); step: 0.01; muted: win.sink && win.sink.audio ? win.sink.audio.muted : false; onMoved: v => Audio.setVolume(win.sink, v) }
                    Label { text: Audio.pct(win.sink) + "%"; size: Tokens.fontSizeSmall; dim: true; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                }
                // now playing
                Rectangle {
                    visible: win.player !== null
                    Layout.fillWidth: true
                    implicitHeight: 112
                    radius: Tokens.rLg
                    color: Colors.surfaceContainerHighest
                    RowLayout {
                        anchors { fill: parent; margins: 8 }
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 96; Layout.preferredHeight: 96
                            radius: Tokens.rMd; color: Colors.surfaceContainerHigh; clip: true
                            Image { anchors.fill: parent; source: win.player ? win.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 192; sourceSize.height: 192 }
                            Glyph { anchors.centerIn: parent; text: "󰎈"; size: 28; visible: !win.player || !win.player.trackArtUrl }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: win.player ? (win.player.trackTitle || "Unknown title") : ""; Layout.fillWidth: true }
                            Label { text: win.player ? (win.player.trackArtist || "") : ""; size: Tokens.fontSizeSmall; dim: true; Layout.fillWidth: true }
                            Label { text: win.player ? (win.player.trackAlbum || "") : ""; size: Tokens.fontSizeTiny; dim: true; regular: true; Layout.fillWidth: true }
                            RowLayout {
                                Layout.topMargin: 4
                                spacing: 4
                                IconButton { glyph: "󰒮"; onClicked: if (win.player && win.player.canGoPrevious) win.player.previous() }
                                IconButton { glyph: win.player && win.player.isPlaying ? "󰏤" : "󰐊"; onClicked: if (win.player && win.player.canTogglePlaying) win.player.togglePlaying() }
                                IconButton { glyph: "󰒭"; onClicked: if (win.player && win.player.canGoNext) win.player.next() }
                                Item { Layout.fillWidth: true }
                                Label { text: win.player ? win.player.identity : ""; size: Tokens.fontSizeTiny; dim: true }
                            }
                        }
                    }
                }
                // the notifications
                Scroller {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    maxHeight: 10000
                    spacing: 8
                    Label { visible: Notifs.count === 0; text: "No notifications"; dim: true; regular: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; topPadding: 40 }
                    Repeater {
                        model: win.groups
                        ColumnLayout {
                            id: grp
                            required property var modelData
                            readonly property bool isOpen: win.expanded[modelData.app] === true || modelData.entries.length === 1
                            Layout.fillWidth: true
                            spacing: 6
                            RowLayout {
                                visible: grp.modelData.entries.length > 1
                                Layout.fillWidth: true
                                Layout.leftMargin: 6; Layout.rightMargin: 4
                                spacing: 8
                                Label { text: grp.modelData.app; size: Tokens.fontSizeSmall; color: Colors.primary; Layout.fillWidth: true }
                                Label { text: grp.modelData.entries.length; size: Tokens.fontSizeTiny; dim: true }
                                IconButton { glyph: grp.isOpen ? "󰅃" : "󰅀"; kind: "action"; small: true; onClicked: { const x = Object.assign({}, win.expanded); x[grp.modelData.app] = !grp.isOpen; win.expanded = x } }
                                IconButton { glyph: "󰎟"; kind: "danger"; small: true; onClicked: Notifs.clearApp(grp.modelData.app) }
                            }
                            Repeater {
                                model: grp.isOpen ? grp.modelData.entries : grp.modelData.entries.slice(0, 1)
                                NotificationCard { required property var modelData; entry: modelData; inCenter: true; Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
