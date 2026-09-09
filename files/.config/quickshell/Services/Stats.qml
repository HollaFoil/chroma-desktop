pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU load from /proc/stat; CPU die temperature from the first k10temp /
// zenpower / coretemp hwmon; GPU load, temperature and VRAM from whichever
// driver is there: nvidia-smi for NVIDIA, the amdgpu sysfs files for AMD.
// Nothing is hardcoded to one machine: with no usable sensor the CPU
// temperature and GPU modules hide.
Singleton {
    id: root
    property int cpu: 0
    property string gpu: "--"
    property int gpuTemp: 0
    property string gpuTip: ""
    property bool gpuAvailable: false
    property int temp: 0
    readonly property int critical: 85
    property real memUsed: 0        // bytes
    property real memTotal: 1
    property real diskUsed: 0
    property real diskTotal: 1
    property string diskMount: "/"

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
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { stat.reload(); root.pollGpu(); mem.reload() } }
    FileView {
        id: mem
        path: "/proc/meminfo"
        onLoaded: {
            const kv = {}
            for (const l of text().split("\n")) { const m = l.match(/^(\w+):\s+(\d+)/); if (m) kv[m[1]] = parseInt(m[2]) * 1024 }
            if (kv.MemTotal) { root.memTotal = kv.MemTotal; root.memUsed = kv.MemTotal - (kv.MemAvailable || 0) }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: Proc.run(["df", "-PB1", root.diskMount], (c, out) => { const f = out.trim().split("\n").pop().split(/\s+/); if (f.length >= 4) { root.diskTotal = parseFloat(f[1]) || 1; root.diskUsed = parseFloat(f[2]) || 0 } }) }
    function gib(b) { return (b / Math.pow(2, 30)).toFixed(1) }

    // Which GPU to read, decided once: "nvidia" when nvidia-smi answers (so a
    // discrete NVIDIA card wins over an AMD iGPU next to it), else "amdgpu"
    // with the /sys/class/drm/cardN/device that has the most VRAM (a discrete
    // Radeon over the CPU's graphics), else nothing and the module hides.
    property string gpuKind: ""
    property string gpuDev: ""
    function detectGpu() {
        Proc.sh("if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then echo nvidia; exit 0; fi; "
              + "best=; bestv=-1; for d in /sys/class/drm/card*/device; do [ -f \"$d/gpu_busy_percent\" ] || continue; "
              + "v=$(cat \"$d/mem_info_vram_total\" 2>/dev/null || echo 0); [ \"$v\" -gt \"$bestv\" ] && { best=$d; bestv=$v; }; done; "
              + "[ -n \"$best\" ] && echo amdgpu \"$best\"", (code, out) => {
            const p = out.trim().split(/\s+/)
            gpuKind = p[0] || ""; gpuDev = p[1] || ""
            gpuAvailable = gpuKind !== ""
            if (gpuAvailable) pollGpu()
        })
    }

    function pollGpu() {
        if (!gpuAvailable) return
        if (gpuKind === "nvidia") {
            Proc.run(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"], (code, out) => {
                if (code !== 0) { gpu = "--"; gpuAvailable = false; return }
                const p = out.trim().split(",").map(s => s.trim())
                if (p.length < 4) return
                gpu = p[0] + "%"; gpuTemp = parseInt(p[1]) || 0
                gpuTip = "GPU " + p[0] + "%  ·  " + p[1] + "°C  ·  " + (parseInt(p[2]) / 1024).toFixed(1) + " / " + (parseInt(p[3]) / 1024).toFixed(1) + " GiB"
            })
        } else if (gpuKind === "amdgpu") {
            // one key=value per line, so a missing file (no VRAM figures on some APUs) shifts nothing
            Proc.sh("d=" + gpuDev + "; echo busy=$(cat \"$d/gpu_busy_percent\" 2>/dev/null); "
                  + "echo used=$(cat \"$d/mem_info_vram_used\" 2>/dev/null); echo total=$(cat \"$d/mem_info_vram_total\" 2>/dev/null); "
                  + "echo temp=$(cat \"$d\"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)", (code, out) => {
                if (code !== 0) { gpu = "--"; gpuAvailable = false; return }
                const kv = {}
                for (const l of out.trim().split("\n")) { const i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = parseInt(l.slice(i + 1)) || 0 }
                if (!("busy" in kv)) return
                gpu = kv.busy + "%"; gpuTemp = Math.round((kv.temp || 0) / 1000)
                gpuTip = "GPU " + kv.busy + "%" + (gpuTemp ? "  ·  " + gpuTemp + "°C" : "")
                       + (kv.total ? "  ·  " + gib(kv.used || 0) + " / " + gib(kv.total) + " GiB" : "")
            })
        }
    }

    // CPU die temperature: the first hwmon whose driver is a CPU sensor. Found
    // by name rather than by PCI path, so it survives hwmon renumbering and
    // works on Intel (coretemp) as well as AMD (k10temp, zenpower).
    property string hwmonPath: ""
    FileView { id: tempFile; path: root.hwmonPath; printErrors: false; onLoaded: root.temp = Math.round(parseInt(text()) / 1000) }
    Timer { interval: 5000; running: root.hwmonPath !== ""; repeat: true; triggeredOnStart: true; onTriggered: tempFile.reload() }
    Component.onCompleted: {
        Proc.sh("for h in /sys/class/hwmon/hwmon*; do case \"$(cat \"$h/name\" 2>/dev/null)\" in k10temp|zenpower|coretemp) [ -f \"$h/temp1_input\" ] && { echo \"$h/temp1_input\"; break; };; esac; done", (c, out) => { hwmonPath = out.trim() })
        detectGpu()
    }
}
