pragma Singleton
import QtQuick
import Quickshell

// Everything that is not a colour: type, radii, alphas, spacing and motion.
// One set for every surface so the bar, its popups, the notifications, the
// launchers and the lock screen read as one thing.
Singleton {
    id: root

    // type: GeistMono Nerd Font Propo, bold nearly everywhere (see Label.regular)
    readonly property string fontFamily: "GeistMono Nerd Font Propo"
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeTiny: 11
    readonly property int fontSizeMicro: 10
    readonly property int fontSizeTitle: 14
    readonly property int fontSizeHeading: 16
    readonly property int fontSizeIcon: 18
    readonly property int fontSizeIconSmall: 14
    readonly property int fontSizeBar: 12

    // the bar
    readonly property int barHeight: 37
    readonly property int barBubbleMargin: 5      // bubble inset from the bar's top and bottom
    readonly property int barBubbleGap: 7         // gap between bubbles
    readonly property int barBubblePadX: 20       // horizontal padding inside a bubble
    readonly property int barCornerRadius: 40     // the launcher and the clock slant into the screen corners

    // radii: cards take the asymmetric 24/10 pair, everything inside steps down
    readonly property int rCardA: 24
    readonly property int rCardB: 10
    readonly property int rLg: 16
    readonly property int rMd: 12
    readonly property int rSm: 10
    readonly property int rXs: 8
    readonly property int rXxs: 6
    readonly property int rPill: 999

    // alphas over Colors.surface (Hyprland blurs behind every qs-* layer)
    readonly property real aBar: 0.5
    readonly property real aCard: 0.62
    readonly property real aSettings: 0.82
    readonly property real aHover: 0.15
    readonly property real aNavActive: 0.18
    readonly property real aActive: 0.25
    readonly property real aSelection: 0.35
    readonly property real aSubtle: 0.05
    readonly property real aBackdrop: 0.35        // the wallpaper strip's screen-wide frost
    readonly property real aDivider: 0.6

    // spacing
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp5: 20
    readonly property int sp6: 24
    readonly property int cardPadX: 16
    readonly property int cardPadY: 14
    readonly property int popupGap: 6             // between the bar and a popup card
    readonly property int popupMinWidth: 340
    readonly property int settingsWidth: 940
    readonly property int rowHeight: 30

    // motion
    readonly property int durFast: 120
    readonly property int durReveal: 160
    readonly property int durNormal: 200
    readonly property int durSlow: 300
    readonly property int easing: Easing.OutCubic

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
