pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

// NetworkManager, BlueZ, the hotspot and Tailscale in one place, plus the
// desktop notifications for connections coming and going (unless the shell
// itself asked for the change moments ago).
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wiredDevices: devices.filter(d => d.type === DeviceType.Wired)
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool anyConnected: devices.some(d => d.connected)
    readonly property bool wifiEnabled: Networking.wifiEnabled
    function setWifiEnabled(on) { Networking.wifiEnabled = on }

    readonly property var wifiIcons: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
    function wifiIcon(strength) { return wifiIcons[Math.min(4, Math.max(0, Math.floor((strength * 100 + 12) / 25)))] }
    function secured(net) { return net.security !== WifiSecurityType.None }
    function activeWifi() {
        if (!wifiDevice) return null
        return wifiDevice.networks.values.find(n => n.connected) ?? null
    }

    // ── Bluetooth ──
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasBluetooth: adapter !== null
    readonly property var btIcons: ({
        "audio-headset": "󰋋", "audio-headphones": "󰋋", "audio-card": "󰓃",
        "input-mouse": "󰍽", "input-keyboard": "󰌌", "input-gaming": "󰊴",
        "phone": "󰄜", "computer": "󰇅"
    })
    function btIcon(name) { return btIcons[name] ?? "󰂯" }
    Timer { id: scanStop; interval: 15000; onTriggered: root.stopScan() }
    function scan() {
        if (!adapter || adapter.discovering) return
        adapter.discovering = true
        scanStop.restart()
    }
    function stopScan() {
        scanStop.stop()
        if (!adapter) return
        if (adapter.discovering) adapter.discovering = false
        // forget every unpaired device BlueZ cached during the scan
        for (const d of adapter.devices.values) if (!d.paired && !d.connected && !d.pairing) d.forget()
    }

    // ── Hotspot (the one saved AP-mode connection) ──
    property string hotspotUuid: ""
    property string hotspotName: ""
    property string hotspotSsid: ""
    property bool hotspotActive: false
    property int hotspotClients: 0
    readonly property bool hasHotspot: hotspotUuid !== "" && wifiDevice !== null
    function refreshHotspot() {
        Proc.sh("nmcli -t -f NAME,UUID,TYPE,ACTIVE connection show | while IFS=: read -r name uuid type active; do [ \"$type\" = 802-11-wireless ] || continue; mode=$(nmcli -g 802-11-wireless.mode connection show \"$uuid\"); [ \"$mode\" = ap ] || continue; ssid=$(nmcli -g 802-11-wireless.ssid connection show \"$uuid\"); printf '%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$uuid\" \"$active\" \"$ssid\"; break; done", (code, out) => {
            const line = out.trim().split("\n")[0]
            if (!line) { hotspotUuid = ""; hotspotActive = false; return }
            const [name, uuid, active, ssid] = line.split("\t")
            hotspotName = name; hotspotUuid = uuid; hotspotSsid = ssid || name
            hotspotActive = active === "yes"
            if (hotspotActive && wifiDevice) {
                Proc.run(["iw", "dev", wifiDevice.name, "station", "dump"], (c, o) => { hotspotClients = (o.match(/^Station /gm) || []).length })
            } else hotspotClients = 0
        })
    }
    function setHotspot(on, cb) {
        if (!hotspotUuid) return
        intend("hotspot")
        Proc.run(["nmcli", "connection", on ? "up" : "down", hotspotUuid], (code, out, err) => {
            refreshHotspot()
            if (cb) cb(code === 0 ? null : (err.trim().split("\n").pop() || "nmcli failed"))
        })
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refreshHotspot() }

    // ── Tailscale ──
    property bool hasTailscale: false
    property bool tailscaleUp: false
    property string tailscaleDetail: ""
    function refreshTailscale() {
        if (!hasTailscale) return
        Proc.run(["tailscale", "status", "--json"], (code, out, err) => {
            if (code !== 0) { tailscaleUp = false; tailscaleDetail = (err.trim() || "tailscaled not running").split("\n").pop(); return }
            try {
                const st = JSON.parse(out)
                tailscaleUp = st.BackendState === "Running"
                const me = st.Self || {}, ips = me.TailscaleIPs || []
                const name = (me.DNSName || "").replace(/\.$/, "").split(".")[0]
                const peers = Object.values(st.Peer || {}).filter(p => p.Online).length
                tailscaleDetail = (tailscaleUp && ips.length) ? (name + " · " + ips[0] + " · " + peers + " peers online") : (st.BackendState || "").toLowerCase()
            } catch (e) { tailscaleDetail = "status unreadable" }
        })
    }
    function setTailscale(on, cb) {
        Proc.run(["tailscale", on ? "up" : "down"], (code, out, err) => {
            refreshTailscale()
            if (code !== 0) {
                const e = err.toLowerCase()
                const hint = (e.indexOf("permission") >= 0 || e.indexOf("access denied") >= 0) ? "  (allow: sudo tailscale set --operator=$USER)" : ""
                if (cb) cb((err.trim().split("\n").pop() || "failed") + hint)
            } else if (cb) cb(null)
        })
    }

    // ── remote desktop (wayvnc over Tailscale, see ~/.local/bin/remote-desktop) ──
    property bool haveVnc: false
    property bool vncActive: false
    property bool vncAutostart: false
    property string vncOutput: ""
    property string vncAddress: ""
    property string vncPort: "5900"
    function refreshVnc() {
        Proc.sh("command -v wayvnc >/dev/null && echo yes || echo no; systemctl --user is-active wayvnc.service; systemctl --user is-enabled wayvnc.service 2>/dev/null || echo disabled; ~/.local/bin/remote-desktop output; tailscale ip -4 2>/dev/null | head -1", (c, out) => {
            const l = out.split("\n")
            haveVnc = l[0] === "yes"; vncActive = l[1] === "active"; vncAutostart = l[2] === "enabled"; vncOutput = l[3] || ""; vncAddress = l[4] || ""
        })
    }
    function setVnc(on, cb) { Proc.run([Hypr.home + "/.local/bin/remote-desktop", on ? "on" : "off"], (c, out, err) => { refreshVnc(); if (cb) cb(c === 0 ? null : (err.trim().split("\n").pop() || "failed")) }) }
    function setVncAutostart(on) { Proc.run([Hypr.home + "/.local/bin/remote-desktop", "autostart", on ? "on" : "off"], () => refreshVnc()) }
    function setVncOutput(name) { Proc.run([Hypr.home + "/.local/bin/remote-desktop", "output", name], () => refreshVnc()) }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refreshVnc() }

    // ── notifications for outside changes ──
    // intents: names of things we changed ourselves in the last 20 s
    property var intents: ({})
    function intend(name) { const i = Object.assign({}, intents); i[name] = Date.now(); intents = i }
    function intended(name) { const t = intents[name]; return t !== undefined && Date.now() - t < 20000 }
    property var known: ({})
    function snapshot() {
        const out = {}
        for (const d of devices) {
            if (!d.connected) continue
            if (d.type === DeviceType.Wired) out["wired:" + d.name] = { kind: "Wired", name: d.name }
            else if (d.type === DeviceType.Wifi) {
                if (d.mode === WifiDeviceMode.Ap) out["hotspot"] = { kind: "Hotspot", name: hotspotSsid || "hotspot" }
                else { const n = d.networks.values.find(x => x.connected); if (n) out["wifi:" + n.name] = { kind: "Wi-Fi", name: n.name } }
            }
        }
        return out
    }
    Timer { id: settle; interval: 700; onTriggered: root.diff() }
    property bool primed: false
    function diff() {
        const now = snapshot()
        if (primed) {
            for (const k in now) if (!known[k] && !intended(k)) announce(now[k], true)
            for (const k in known) if (!now[k] && !intended(k)) announce(known[k], false)
        }
        known = now
        primed = true
    }
    function announce(item, up) {
        let summary, body = "", icon
        if (item.kind === "Hotspot") { summary = "Hotspot " + (up ? "on" : "off"); body = item.name; icon = "network-wireless-hotspot-symbolic" }
        else { summary = item.kind + (up ? " connected" : " disconnected"); body = item.kind === "Wi-Fi" ? item.name : ""; icon = item.kind === "Wi-Fi" ? "network-wireless-symbolic" : "network-wired-symbolic" }
        Notify.send(summary, body, icon)
    }
    Connections { target: Networking.devices; function onObjectInsertedPost() { settle.restart() } function onObjectRemovedPost() { settle.restart() } }
    Instantiator {
        model: Networking.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { settle.restart() }
            function onStateChanged() { settle.restart() }
        }
    }

    Component.onCompleted: {
        Proc.run(["sh", "-c", "command -v tailscale"], (code) => { hasTailscale = code === 0; refreshTailscale() })
        refreshHotspot()
        refreshVnc()
        settle.restart()
    }
}
