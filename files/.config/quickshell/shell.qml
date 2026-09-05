import QtQuick
import Quickshell
import Quickshell.Io
import qs.Bar
import qs.Popups
import qs.Settings
import qs.Notifications
import qs.Launcher
import qs.Overlays
import qs.Lock
import qs.Services
import qs.Theme

ShellRoot {
    id: shell
    // Development aid: QS_SCREENS="DP-2,HDMI-A-2" limits the shell to those outputs.
    readonly property var onlyScreens: (Quickshell.env("QS_SCREENS") || "").split(",").filter(s => s.length > 0)
    readonly property var screens: Quickshell.screens.filter(s => onlyScreens.length === 0 || onlyScreens.indexOf(s.name) >= 0)

    Variants {
        model: shell.screens
        Scope {
            id: perScreen
            required property var modelData
            Bar { screen: perScreen.modelData }
            PopupHost { modelData: perScreen.modelData }
            Toasts { modelData: perScreen.modelData; allScreens: shell.screens }
            OsdWindow { modelData: perScreen.modelData; allScreens: shell.screens }
        }
    }

    LazyLoader { id: settingsLoader; loading: true; SettingsWindow { allowedScreens: shell.screens } }
    LazyLoader { id: notifsLoader; loading: true; ControlCenter { allowedScreens: shell.screens } }
    LazyLoader { id: launcherLoader; loading: true; AppLauncher { allowedScreens: shell.screens } }
    LazyLoader { id: clipLoader; loading: true; ClipPicker { allowedScreens: shell.screens } }
    LazyLoader { id: cheatLoader; loading: true; Cheatsheet { allowedScreens: shell.screens } }
    LazyLoader { id: stripLoader; loading: true; WallStrip { allowedScreens: shell.screens } }
    LockSession {}
    LazyLoader { id: lockPreviewLoader; LockPreview { screen: shell.screens[0] } }
    Connections {
        target: Overlays
        function onSettingsRequested(page) { settingsLoader.item.show(page) }
        function onSettingsToggle() { settingsLoader.item.toggle() }
        function onNotifsToggle() { notifsLoader.item.toggle() }
        function onLauncherToggle() { launcherLoader.item.toggle() }
        function onClipToggle() { clipLoader.item.toggle() }
        function onCheatsheetToggle() { cheatLoader.item.toggle() }
        function onWallStripToggle() { stripLoader.item.toggle() }
    }
    IpcHandler { target: "cheatsheet"; function toggle(): void { cheatLoader.item.toggle() } }
    IpcHandler { target: "wallstrip"; function toggle(): void { stripLoader.item.toggle() } }
    IpcHandler {
        target: "lock"
        function lock(): void { Lock.lock() }
        function locked(): bool { return Lock.locked }
        // a look at the screen on the shell's first output, no lock involved
        function preview(greeter: bool): void { lockPreviewLoader.active = true; lockPreviewLoader.item.greeterLook = greeter; lockPreviewLoader.item.isOpen = !lockPreviewLoader.item.isOpen }
    }
    IpcHandler {
        target: "osd"
        function volume(): void { const s = Audio.defaultSink; Osd.armed = true; Osd.show("volume", Audio.speakerIcon(Audio.pct(s), s && s.audio && s.audio.muted), Math.min(1, s && s.audio ? s.audio.volume : 0), s && s.audio ? s.audio.muted : false) }
    }
    IpcHandler { target: "launcher"; function toggle(): void { launcherLoader.item.toggle() } }
    IpcHandler { target: "clip"; function toggle(): void { clipLoader.item.toggle() } }
    IpcHandler {
        target: "notifs"
        function toggle(): void { notifsLoader.item.toggle() }
        function dnd(on: bool): void { Notifs.dnd = on }
        function clear(): void { Notifs.clearAll() }
        function count(): int { return Notifs.count }
    }
    IpcHandler {
        target: "settings"
        function toggle(): void { settingsLoader.item.toggle() }
        function open(page: string): void { settingsLoader.item.show(page) }
    }

    // Session-long duties (the audio router, network notifications) live in
    // these singletons; touching them here brings them up with the shell.
    Component.onCompleted: {
        Audio.applySoon(); Net.refreshHotspot(); Osd.armed = false
        Proc.sh('f="${XDG_RUNTIME_DIR:-/tmp}/qs-lock-at-start"; if [ -e "$f" ]; then rm -f "$f"; echo lock; fi', (c, out) => { if (out.trim() === "lock") Lock.lock() })
    }

    IpcHandler {
        target: "popup"
        function toggle(name: string): void {
            const s = shell.screens[0]
            if (Popups.current === name) Popups.close()
            else Popups.open(name, s, 0, 10, name === "launcher" ? "left" : "right", null)
        }
        function close(): void { Popups.close() }
    }
}
