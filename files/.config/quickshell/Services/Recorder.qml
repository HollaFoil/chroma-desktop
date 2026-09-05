pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screen recording. gpu-screen-recorder when installed (per-app audio include
// and exclude, merged sources), wf-recorder otherwise (one audio source).
// Target: a whole screen, a window (picked with slurp from the client list)
// or a region (drawn with slurp). Files go to ~/Videos/Recordings.
Singleton {
    id: root
    property bool haveGsr: false
    readonly property string backend: haveGsr ? "gpu-screen-recorder" : "wf-recorder"
    property bool recording: false
    property bool starting: false
    property string outFile: ""
    property real startedAt: 0
    property int elapsed: 0
    property string status: ""
    readonly property string dir: Quickshell.env("HOME") + "/Videos/Recordings"

    // options, persisted
    property string target: "screen"          // screen | window | region
    property string screenName: ""
    property bool desktopAudio: true
    property bool micAudio: false
    property string appMode: "all"            // all | only | except   (gpu-screen-recorder only)
    property var apps: []                     // application names for only/except
    property int fps: 60
    property string encoder: "auto"          // auto (GPU, CPU if the GPU cannot) | cpu   (gpu-screen-recorder only)
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/recorder.json"
    FileView { id: state; path: root.statePath; printErrors: false
        onLoaded: { try { const j = JSON.parse(text()); root.target = j.target ?? root.target; root.screenName = j.screenName ?? ""; root.desktopAudio = j.desktopAudio ?? true
                          root.micAudio = j.micAudio ?? false; root.appMode = j.appMode ?? "all"; root.apps = j.apps ?? []; root.fps = j.fps ?? 60; root.encoder = j.encoder ?? "auto" } catch (e) {} } }
    function save() { state.setText(JSON.stringify({ target, screenName, desktopAudio, micAudio, appMode, apps, fps, encoder }, null, 1)) }
    function toggleApp(name) { const i = apps.indexOf(name); apps = i >= 0 ? apps.filter(a => a !== name) : apps.concat([name]); save() }

    Timer { interval: 1000; running: root.recording; repeat: true; onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000) }
    function clock() { const m = Math.floor(elapsed / 60), s = elapsed % 60; return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s }

    function toggle() { if (recording) stop(); else start() }
    function start() {
        if (recording || starting) return
        starting = true; status = ""
        const t = new Date()
        const stamp = t.getFullYear() + "-" + String(t.getMonth() + 1).padStart(2, "0") + "-" + String(t.getDate()).padStart(2, "0") + "_" + String(t.getHours()).padStart(2, "0") + "-" + String(t.getMinutes()).padStart(2, "0") + "-" + String(t.getSeconds()).padStart(2, "0")
        outFile = dir + "/" + stamp + ".mp4"
        if (target === "screen") {
            const name = screenName || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            launch({ output: name })
        } else if (target === "region") {
            Proc.run(["slurp", "-f", "%x,%y %wx%h"], (code, out) => { if (code !== 0 || !out.trim()) { root.abort("no region picked") } else root.launch({ geometry: out.trim() }) })
        } else {
            // the windows on screen right now (each monitor's active workspace) as rectangles slurp snaps to
            Proc.sh("ws=$(hyprctl -j monitors | jq -c '[.[].activeWorkspace.id]'); hyprctl -j clients | jq -r --argjson ws \"$ws\" '.[] | select(.mapped and (.hidden | not) and ((.workspace.id) as $w | $ws | index($w) != null)) | \"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1]) \\(.title)\"' | slurp -r -f '%x,%y %wx%h'", (code, out) => {
                if (code !== 0 || !out.trim()) root.abort("no window picked"); else root.launch({ geometry: out.trim() })
            })
        }
    }
    function abort(msg) { starting = false; status = msg }
    function command(where) {
        let cmd
        if (haveGsr) {
            // this machine's NVIDIA driver speaks an older NVENC API than gsr's FFmpeg wants, so the GPU
            // path can fail; -fallback-cpu-encoding keeps the recording going on the CPU in that case
            cmd = ["gpu-screen-recorder", "-f", String(fps), "-o", outFile, "-fallback-cpu-encoding", "yes"]
            if (encoder === "cpu") cmd.push("-encoder", "cpu")
            if (where.output) cmd.push("-w", where.output)
            else { const m = where.geometry.match(/(\d+),(\d+) (\d+)x(\d+)/); cmd.push("-w", "region", "-region", m[3] + "x" + m[4] + "+" + m[1] + "+" + m[2]) }
            const srcs = []
            if (desktopAudio) {
                if (appMode === "only") for (const a of apps) srcs.push("app:" + a)
                else if (appMode === "except") { if (apps.length) srcs.push("app-inverse:" + apps.join("|app-inverse:")); else srcs.push("default_output") }
                else srcs.push("default_output")
            }
            if (micAudio) srcs.push("default_input")
            if (srcs.length) cmd.push("-a", srcs.join("|"))
        } else {
            cmd = ["wf-recorder", "-f", outFile, "-r", String(fps)]
            if (where.output) cmd.push("-o", where.output); else cmd.push("-g", where.geometry)
            if (desktopAudio || micAudio) {
                const dev = desktopAudio ? "@DEFAULT_MONITOR@" : "@DEFAULT_SOURCE@"
                cmd.push("--audio=" + dev)
                if (desktopAudio && micAudio) status = "wf-recorder records one audio source: desktop audio (install gpu-screen-recorder to mix in the microphone)"
            }
        }
        return cmd
    }
    function launch(where) {
        Proc.run(["mkdir", "-p", dir], () => {
            rec.command = command(where)
            rec.running = true
            startedAt = Date.now(); elapsed = 0
            recording = true; starting = false
        })
    }
    // Stop, then open the folder once the file is written. SIGINT lets the
    // recorder finish the file; a recorder still alive after 3 s gets SIGTERM.
    property bool openAfter: false
    function stop() {
        if (!recording) return
        openAfter = true
        if (rec.processId) { Proc.detach(["kill", "-INT", String(rec.processId)]); stopHard.restart() }
    }
    Timer { id: stopHard; interval: 3000; onTriggered: if (root.recording && rec.processId) Proc.detach(["kill", "-TERM", String(rec.processId)]) }
    Process {
        id: rec
        property string err: ""
        stderr: StdioCollector { onStreamFinished: rec.err = text }
        onExited: (code, st) => {
            const was = root.recording
            root.recording = false; root.starting = false
            const wanted = root.openAfter; root.openAfter = false
            if (!was) return
            stopHard.stop()
            const ok = code === 0 || code === 130 || code === 2 || code === 143
            if (ok) {
                Notify.send("Recording saved", root.outFile, "camera-video-symbolic")
                if (wanted) Proc.detach(["xdg-open", root.dir])
            } else { root.status = root.backend + " failed (" + code + "): " + (rec.err.trim().split("\n").pop() || "see journal"); Notify.send("Recording failed", root.status, "dialog-error") }
        }
    }
    Component.onCompleted: Proc.sh("command -v gpu-screen-recorder", (c) => { haveGsr = c === 0 })
}
