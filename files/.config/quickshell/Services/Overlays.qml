pragma Singleton
import QtQuick
import Quickshell

// Requests for the big surfaces (settings, later the launcher, cheatsheet,
// strip, lock), so a bar module or an IPC call can ask without knowing who
// owns the window. shell.qml wires the signals to the windows.
Singleton {
    signal settingsRequested(string page)
    signal settingsToggle()
    signal notifsToggle()
    signal launcherToggle()
    signal clipToggle()
    function openSettings(page) { settingsRequested(page ?? "") }
    function toggleNotifs() { notifsToggle() }
    function toggleLauncher() { launcherToggle() }
    function toggleClip() { clipToggle() }
}
