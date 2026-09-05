import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets
import qs.Services

// The overlay each screen keeps for the bar's popups: shows whichever panel
// Popups says is open on this screen, under the module that opened it.
OverlayWindow {
    id: host
    required property var modelData
    screen: modelData
    open: Popups.current !== "" && Popups.screen === modelData
    side: Popups.side
    anchorX: Popups.anchorX
    anchorRight: Popups.anchorRight
    onDismissed: if (Popups.screen === modelData) Popups.close()

    readonly property var panels: ({
        launcher: launcherComp, audio: audioComp, network: networkComp, tray: trayComp, calendar: calendarComp, record: recordComp
    })
    Component { id: launcherComp; LauncherMenu {} }
    Component { id: audioComp; AudioPanel {} }
    Component { id: networkComp; NetworkPanel {} }
    Component { id: trayComp; TrayMenu {} }
    Component { id: calendarComp; Calendar {} }
    Component { id: recordComp; RecordPanel {} }

    Card {
        minWidth: Popups.current === "calendar" || Popups.current === "tray" ? 0 : Tokens.popupMinWidth
        Loader {
            Layout.fillWidth: true
            sourceComponent: host.open ? (host.panels[Popups.current] ?? null) : null
        }
    }
}
