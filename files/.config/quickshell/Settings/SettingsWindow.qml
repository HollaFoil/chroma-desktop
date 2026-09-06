import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Theme
import qs.Widgets
import qs.Services

// Settings: a window in the middle of the focused screen.
//     ┌──────────────┬──────────────────────────────┐
//     │ 󰍉 search     │  Page title                  │
//     │ SYSTEM       │  subtitle                    │
//     │  About       │  ┌ Group ─────────────────┐  │
//     │  Accounts    │  │ setting ....  [control] │  │
//     │ DESKTOP      │  │ setting ....  [control] │  │
//     │  ...         │  └────────────────────────┘  │
//     └──────────────┴──────────────────────────────┘
// Pages are built when first shown and kept. The search filters the nav by
// each page's title, blurb, keywords and (once built) its rows' labels, and
// filters the rows of the open page.
OverlayWindow {
    id: win
    placement: "center"
    property bool isOpen: false
    property int current: 0
    property var allowedScreens: Quickshell.screens
    open: isOpen
    onDismissed: { if (Dropdown.open) Dropdown.close(); else isOpen = false }

    // id: what `qs ipc call settings open <id>` and the search use; aliases: old names
    readonly property var pages: [
        { id: "about",         title: "About",              glyph: "󰋽", group: "System",   comp: aboutComp,       blurb: "OS, versions, hardware", keywords: "fastfetch kernel cpu gpu memory disk version system info" },
        { id: "accounts",      title: "Accounts",           glyph: "󰀄", group: "System",   comp: accountsComp,    blurb: "You, this machine, sessions", keywords: "user name password avatar hostname login greeter autologin logout session" },
        { id: "datetime",      title: "Date & Time",        glyph: "󰃰", group: "System",   comp: dateTimeComp,    blurb: "Clock, time zone", keywords: "clock timezone ntp 24 hour 12 hour seconds date" },
        { id: "region",        title: "Region & Language",  glyph: "󰗊", group: "System",   comp: regionComp,      blurb: "Language, formats", keywords: "locale language formats numbers currency paper measurement LC_TIME" },
        { id: "power",         title: "Power",              glyph: "󰂄", group: "System",   comp: powerComp,       blurb: "Profile, idle, batteries", keywords: "battery performance balanced saver idle lock screen off suspend dpms hypridle sleep" },
        { id: "defaults",      title: "Default apps",       glyph: "󰀻", group: "System",   comp: defaultsComp,    blurb: "Browser, files, media", keywords: "browser mail terminal file manager pdf image video music mime xdg-open" },
        { id: "a11y",          title: "Accessibility",      glyph: "󰖏", group: "System",   comp: a11yComp,        blurb: "Text size, motion, cursor", keywords: "large text scaling zoom magnifier reduce motion animations cursor size sticky keys" },
        { id: "updates",       title: "Updates",            glyph: "󰚰", group: "System",   comp: updatesComp,     blurb: "Packages, firmware", keywords: "pacman yay aur flatpak fwupd firmware upgrade" },
        { id: "appearance",    title: "Appearance",         glyph: "󰏘", group: "Desktop",  comp: appearanceComp,  blurb: "Theme, fonts, decoration", keywords: "look theme gtk icons cursor font dark light palette matugen rounding opacity blur shadow animations" , aliases: ["look"] },
        { id: "windows",       title: "Windows",            glyph: "󱂬", group: "Desktop",  comp: windowsComp,     blurb: "Layout, gaps, focus", keywords: "tiling dwindle master gaps border snap floating focus" },
        { id: "workspaces",    title: "Workspaces",         glyph: "󰕰", group: "Desktop",  comp: workspacesComp,  blurb: "Per-monitor banks", keywords: "workspace bank monitor primary special scratchpad back and forth" },
        { id: "keybinds",      title: "Keybinds",           glyph: "󰌌", group: "Desktop",  comp: keybindsComp,    blurb: "Every action and its keys", keywords: "shortcut hotkey bind key combination command" },
        { id: "notifications", title: "Notifications",      glyph: "󰂚", group: "Desktop",  comp: notifsComp,      blurb: "Toasts, do not disturb", keywords: "toast popup dnd do not disturb timeout history apps mute" },
        { id: "shell",         title: "Shell",              glyph: "󰍜", group: "Desktop",  comp: shellComp,       blurb: "Bar, OSD, launcher", keywords: "bar modules tray stats media clock osd volume launcher" },
        { id: "wallpapers",    title: "Wallpapers",         glyph: "󰸉", group: "Desktop",  comp: wallpapersComp,  blurb: "Pick one; the palette follows", keywords: "background image setwall matugen" },
        { id: "widgets",       title: "Widgets",            glyph: "󰘔", group: "Desktop",  comp: widgetsComp,     blurb: "On the desktop", keywords: "desktop clock calendar weather notes shortcuts arrange" },
        { id: "displays",      title: "Displays",           glyph: "󰍹", group: "Hardware", comp: displaysComp,    blurb: "Modes, layout, scale, colour", keywords: "monitor resolution refresh rate hz scale rotation orientation position arrange vrr hdr 10 bit colour color mirror", aliases: ["monitors"] },
        { id: "mouse",         title: "Mouse",              glyph: "󰍽", group: "Hardware", comp: mouseComp,       blurb: "Pointer, touchpad, cursor", keywords: "pointer sensitivity acceleration flat natural scroll left handed touchpad tap cursor", aliases: ["input"] },
        { id: "keyboard",      title: "Keyboard",           glyph: "󰌌", group: "Hardware", comp: keyboardComp,    blurb: "Layouts, repeat, numlock", keywords: "layout variant xkb options compose caps lock repeat rate delay numlock" },
        { id: "audio",         title: "Audio",              glyph: "󰕾", group: "Hardware", comp: audioComp,       blurb: "Devices, per-app output", keywords: "volume sound sink source output input microphone pipewire" },
        { id: "bluetooth",     title: "Bluetooth",          glyph: "󰂯", group: "Hardware", comp: bluetoothComp,   blurb: "Pair and connect", keywords: "pair device headset adapter" },
        { id: "storage",       title: "Storage",            glyph: "󰋊", group: "Hardware", comp: storageComp,     blurb: "Disks and mounts", keywords: "disk drive partition mount usb udisks space" },
        { id: "wifi",          title: "Wi-Fi",              glyph: "󰖩", group: "Network",  comp: wifiComp,        blurb: "Networks, hotspot", keywords: "wireless network ssid password hotspot" },
        { id: "connections",   title: "Connections",        glyph: "󰈀", group: "Network",  comp: connectionsComp, blurb: "Wired, Tailscale, remote", keywords: "ethernet wired vpn tailscale remote desktop vnc" },
        { id: "options",       title: "All options",        glyph: "󰒓", group: "Advanced", comp: allComp,         blurb: "Every Hyprland option", keywords: "hyprland raw option variable" },
        { id: "config",        title: "Config & logs",      glyph: "󰈙", group: "Advanced", comp: configComp,      blurb: "Files, reload, logs", keywords: "edit lua reload restart journal log errors editor" }
    ]
    readonly property var groups: ["System", "Desktop", "Hardware", "Network", "Advanced"]
    Component { id: aboutComp; AboutPage {} }
    Component { id: accountsComp; AccountsPage {} }
    Component { id: dateTimeComp; DateTimePage {} }
    Component { id: regionComp; RegionPage {} }
    Component { id: powerComp; PowerPage {} }
    Component { id: defaultsComp; DefaultAppsPage {} }
    Component { id: a11yComp; AccessibilityPage {} }
    Component { id: updatesComp; UpdatesPage {} }
    Component { id: appearanceComp; AppearancePage {} }
    Component { id: windowsComp; WindowsPage {} }
    Component { id: workspacesComp; WorkspacesPage {} }
    Component { id: keybindsComp; KeybindsPage { host: win } }
    Component { id: notifsComp; NotificationsPage {} }
    Component { id: shellComp; ShellPage {} }
    Component { id: wallpapersComp; WallpapersPage {} }
    Component { id: widgetsComp; WidgetsPage {} }
    Component { id: displaysComp; DisplaysPage {} }
    Component { id: mouseComp; MousePage {} }
    Component { id: keyboardComp; KeyboardPage {} }
    Component { id: audioComp; AudioPage {} }
    Component { id: bluetoothComp; BluetoothPage {} }
    Component { id: storageComp; StoragePage {} }
    Component { id: wifiComp; WifiPage {} }
    Component { id: connectionsComp; ConnectionsPage {} }
    Component { id: allComp; AllOptionsPage {} }
    Component { id: configComp; ConfigPage {} }

    property var built: ({})
    function pageIndex(name) {
        if (!name) return -1
        const n = name.toLowerCase()
        let i = pages.findIndex(p => p.id === n || (p.aliases || []).indexOf(n) >= 0)
        if (i < 0) i = pages.findIndex(p => p.title.toLowerCase().startsWith(n))
        return i
    }
    function show(page) {
        const focused = Hyprland.focusedMonitor
        const s = allowedScreens.find(sc => focused && sc.name === focused.name) ?? allowedScreens[0]
        if (s) screen = s
        const i = pageIndex(page)
        if (i >= 0) current = i
        const b = Object.assign({}, built); b[current] = true; built = b
        isOpen = true
    }
    function toggle() { if (isOpen) isOpen = false; else show("") }
    function select(i) { current = i; const b = Object.assign({}, built); b[i] = true; built = b }
    onIsOpenChanged: if (!isOpen) { Dropdown.close(); search.text = "" }

    function pageHit(i) { const p = pages[i]; return SettingsSearch.pageMatches(i, p.title + " " + p.blurb + " " + p.keywords + " " + p.group) }
    readonly property var hits: { SettingsSearch.q; SettingsSearch.registry; return pages.map((p, i) => pageHit(i)) }
    onHitsChanged: {
        // searching: stay on the current page while it matches, otherwise go to the first page that does
        if (!SettingsSearch.active || hits[current]) return
        const i = hits.indexOf(true)
        if (i >= 0) select(i)
    }

    Item {
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight
        Card {
            id: card
            slanted: false
            alpha: Tokens.aSettings
            minWidth: Tokens.settingsWidth
            padX: 14; padY: 12
            RowLayout {
                spacing: 0
                // nav
                ColumnLayout {
                    Layout.preferredWidth: 168
                    Layout.maximumWidth: 168
                    Layout.alignment: Qt.AlignTop
                    Layout.rightMargin: 12
                    spacing: 2
                    Entry {
                        id: search
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4
                        placeholder: "󰍉  Search settings"
                        onTextChanged: SettingsSearch.query = text
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape && text.length > 0) { text = ""; event.accepted = true }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { const i = win.hits.indexOf(true); if (i >= 0) win.select(i); event.accepted = true }
                        }
                    }
                    Scroller {
                        Layout.fillWidth: true
                        maxHeight: 810
                        spacing: 2
                        Repeater {
                            model: win.groups
                            ColumnLayout {
                                id: grp
                                required property string modelData
                                required property int index
                                readonly property var members: { win.hits; return win.pages.map((p, i) => ({ p, i })).filter(x => x.p.group === grp.modelData && win.hits[x.i]) }
                                visible: members.length > 0
                                Layout.fillWidth: true
                                spacing: 2
                                Label { text: grp.modelData.toUpperCase(); size: Tokens.fontSizeMicro; dim: true; leftPadding: 10; topPadding: grp.index === 0 ? 0 : 6; bottomPadding: 1 }
                                Repeater {
                                    model: grp.members
                                    ListRow {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        padX: 10; padY: 4
                                        implicitHeight: 25
                                        spacing: 10
                                        readonly property bool on: win.current === modelData.i
                                        color: on ? Tokens.alpha(Colors.primary, Tokens.aNavActive) : hovered ? Tokens.alpha(Colors.primary, Tokens.aHover) : "transparent"
                                        onClicked: win.select(modelData.i)
                                        Glyph { text: modelData.p.glyph; size: 16; Layout.preferredWidth: 20 }
                                        Label { text: modelData.p.title; size: Tokens.fontSizeSmall; color: on ? Colors.primary : Colors.surfaceFg; Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                        Label { visible: !win.hits.some(h => h); text: "no page matches"; size: Tokens.fontSizeSmall; dim: true; regular: true; leftPadding: 10 }
                    }
                }
                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Tokens.alpha(Colors.outlineVariant, Tokens.aDivider) }
                // body
                Item {
                    Layout.preferredWidth: 740
                    Layout.minimumWidth: 740
                    Layout.leftMargin: 12
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: 810
                    Repeater {
                        model: win.pages.length
                        Loader {
                            required property int index
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            active: win.built[index] === true
                            visible: win.current === index
                            sourceComponent: win.pages[index].comp
                            onLoaded: if (item.settingsPageIndex !== undefined) item.settingsPageIndex = index
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                        }
                    }
                }
            }
        }
        DropdownLayer { anchors.fill: parent }
    }
}
