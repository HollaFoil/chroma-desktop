pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the volume and brightness keys show: one small bar at the bottom of
// the focused screen for a moment. Driven by the Pipewire default nodes and
// the backlight sysfs file, so it also reacts to changes made elsewhere;
// quiet while an audio popup is open (the slider is the feedback then).
Singleton {
    id: root
    property bool visible: false
    property string glyph: ""
    property real value: 0
    property bool muted: false
    property string kind: ""
    property bool armed: false
    Timer { id: hide; interval: 1500; onTriggered: root.visible = false }
    Timer { interval: 2500; running: true; onTriggered: root.armed = true }

    function show(kind, glyph, value, muted) {
        if (!armed) return
        if (Popups.current !== "") return
        root.kind = kind; root.glyph = glyph; root.value = value; root.muted = muted
        visible = true
        hide.restart()
    }

    readonly property var sink: Audio.defaultSink
    readonly property var source: Audio.defaultSource
    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        function onVolumeChanged() { root.show("volume", Audio.speakerIcon(Math.round(target.volume * 100), target.muted), Math.min(1, target.volume), target.muted) }
        function onMutedChanged() { root.show("volume", Audio.speakerIcon(Math.round(target.volume * 100), target.muted), Math.min(1, target.volume), target.muted) }
    }
    Connections {
        target: root.source && root.source.audio ? root.source.audio : null
        function onMutedChanged() { root.show("mic", Audio.micIcon(target.muted), Math.min(1, target.volume), target.muted) }
    }

    // backlight, if the machine has one
    property string backlightPath: ""
    property real backlightMax: 1
    FileView { id: bl; path: root.backlightPath; watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { const v = parseInt(text()) || 0; root.show("brightness", "󰃠", Math.min(1, v / root.backlightMax), false) } }
    Component.onCompleted: Proc.sh("for d in /sys/class/backlight/*; do [ -f \"$d/brightness\" ] && { printf '%s %s' \"$d/brightness\" \"$(cat \"$d/max_brightness\")\"; break; }; done", (c, out) => {
        const p = out.trim().split(" ")
        if (p.length === 2) { root.backlightMax = parseInt(p[1]) || 1; root.backlightPath = p[0] }
    })
}
