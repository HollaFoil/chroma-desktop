pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ~/.cache/hypr/binds.json: what every action is bound to, written by the
// Hyprland config (lib/actions.lua) at the end of every load. Watched, so
// the keybinds page and the cheatsheet follow a reload by themselves.
Singleton {
    id: root
    readonly property string path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/hypr/binds.json"
    property var data: ({ categories: [], actions: [], columns: [] })
    readonly property var actions: data.actions ?? []
    readonly property var categories: data.categories ?? []
    readonly property var columns: data.columns ?? []
    property int revision: 0

    FileView {
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()); root.revision++ } catch (e) { console.warn("Binds: bad JSON: " + e) } }
    }

    function action(id) { return actions.find(a => a.id === id) ?? null }
    function keysOf(id) { const a = action(id); return a ? (a.keys ?? []) : [] }

    // Display names for keysyms that are not self-explanatory (the stored bind keeps the keysym).
    readonly property var keyLabels: ({
        "XF86AudioRaiseVolume": "󰝝 Volume up key", "XF86AudioLowerVolume": "󰝞 Volume down key",
        "XF86AudioMute": "󰝟 Mute key", "XF86AudioMicMute": "󰍭 Mic mute key",
        "XF86MonBrightnessUp": "󰃠 Brightness up key", "XF86MonBrightnessDown": "󰃞 Brightness down key",
        "XF86AudioPlay": "󰐊 Play key", "XF86AudioPause": "󰏤 Pause key",
        "XF86AudioNext": "󰒭 Next key", "XF86AudioPrev": "󰒮 Previous key", "XF86AudioStop": "󰓛 Stop key",
        "mouse:272": "Left click", "mouse:273": "Right click", "mouse:274": "Middle click",
        "mouse:275": "Mouse button 4", "mouse:276": "Mouse button 5",
        "mouse_down": "Scroll down", "mouse_up": "Scroll up",
        "slash": "/", "comma": ",", "period": ".", "semicolon": ";", "apostrophe": "'",
        "bracketleft": "[", "bracketright": "]", "minus": "-", "equal": "=", "grave": "`", "backslash": "\\",
        "Return": "Enter", "space": "Space", "Escape": "Esc", "Print": "PrtSc", "TAB": "Tab"
    })
    function prettyCombo(combo) {
        const parts = combo.split("+").map(p => p.trim())
        if (parts.length && keyLabels[parts[parts.length - 1]]) parts[parts.length - 1] = keyLabels[parts[parts.length - 1]]
        return parts.join(" + ")
    }
}
