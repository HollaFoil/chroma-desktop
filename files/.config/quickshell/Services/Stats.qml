pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU load from /proc/stat, GPU from nvidia-smi, the k10temp die temperature.
Singleton {
    id: root
    property int cpu: 0
    property string gpu: "--"
    property int gpuTemp: 0
    property string gpuTip: ""
    property bool gpuAvailable: true
    property int temp: 0
    readonly property int critical: 85

    property var lastCpu: null
    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0)
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total, di = idle - root.lastCpu.idle
                if (dt > 0) root.cpu = Math.round((dt - di) * 100 / dt)
            }
            root.lastCpu = { idle, total }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { stat.reload(); root.pollGpu() } }

    function pollGpu() {
        if (!gpuAvailable) return
        Proc.run(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"], (code, out) => {
            if (code !== 0) { gpu = "--"; gpuAvailable = false; return }
            const p = out.trim().split(",").map(s => s.trim())
            if (p.length < 4) return
            gpu = p[0] + "%"; gpuTemp = parseInt(p[1]) || 0
            gpuTip = "GPU " + p[0] + "%  ·  " + p[1] + "°C  ·  " + (parseInt(p[2]) / 1024).toFixed(1) + " / " + (parseInt(p[3]) / 1024).toFixed(1) + " GiB"
        })
    }

    // k10temp by PCI path so it survives hwmon renumbering
    property string hwmonPath: ""
    FileView { id: tempFile; path: root.hwmonPath; printErrors: false; onLoaded: root.temp = Math.round(parseInt(text()) / 1000) }
    Timer { interval: 5000; running: root.hwmonPath !== ""; repeat: true; onTriggered: tempFile.reload() }
    Component.onCompleted: Proc.sh("ls -d /sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon*/temp1_input 2>/dev/null | head -1", (c, out) => { hwmonPath = out.trim() })
}
