import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Widgets

// One screen for logging in and for unlocking (the picture wallgreet drew):
//   idle    date top-left, sleep/restart/power top-right, the clock as two big
//           numbers, "Press any key" at the bottom
//   form    the clock fades out and the form fades in where it was: your name,
//           a pill input with an Enter glyph; in the greeter also the session
//           as a small drop-up list bottom-left. Any key, a scroll, or a drag
//           gets you there; Escape, or a while of nothing, fades it back.
// The state (which user, busy, the error) lives in `model`, shared by every
// screen's copy so typing on one monitor shows on all.
Item {
    id: root
    required property var model          // Lock or Greeter session state
    property string wallpaper: ""
    property bool greeter: false
    property bool takesInput: true
    property bool showControls: true     // the form and buttons: only on the main greeter screen

    readonly property real p: model.formOpen ? 1 : 0
    property real q: p
    Behavior on q { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    readonly property int margin: 48
    readonly property int clockLift: 40
    readonly property int formDrop: 30

    Component.onCompleted: if (model.formOpen && takesInput) pw.forceActiveFocus()

    // ── backdrop ──
    Rectangle { anchors.fill: parent; color: Colors.surface }
    Image {
        anchors.fill: parent
        source: root.wallpaper ? (root.wallpaper.startsWith("/") ? "file://" + root.wallpaper : root.wallpaper) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        sourceSize.width: width; sourceSize.height: height
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.30) }

    // any click / drag / scroll opens or closes the form. One press is one
    // gesture: once a drag has switched the state it is spent until release.
    MouseArea {
        anchors.fill: parent
        property real pressX: 0; property real pressY: 0
        property bool spent: false
        onPressed: mouse => { pressX = mouse.x; pressY = mouse.y; spent = false; root.model.touch() }
        onPositionChanged: mouse => {
            if (!pressed || spent) return
            if (Math.hypot(mouse.x - pressX, mouse.y - pressY) < 80) return
            spent = true
            if (root.model.formOpen) { if (root.model.password.length === 0) root.model.formOpen = false }
            else root.model.open()
        }
        onClicked: if (!spent && !root.model.formOpen) root.model.open()
        onReleased: spent = false
        onWheel: { if (!root.model.formOpen) root.model.open(); else if (!root.model.password.length) root.model.formOpen = false }
    }
    // keys reach the form from any screen
    FocusScope {
        id: scope
        anchors.fill: parent
        focus: root.takesInput
        Keys.onPressed: event => {
            root.model.touch()
            if (event.key === Qt.Key_Escape) { if (root.model.formOpen) root.model.formOpen = false; else root.model.escapeIdle(); event.accepted = true; return }
            if (!root.model.formOpen) {
                root.model.open()
                if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 0x20 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) root.model.password = event.text
                event.accepted = true
                return
            }
            if (!pw.activeFocus) { pw.forceActiveFocus(); if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 0x20) { root.model.password += event.text; event.accepted = true } }
        }
    }
    Connections { target: root.model; function onFormOpenChanged() { if (root.model.formOpen && root.takesInput) pw.forceActiveFocus(); else scope.forceActiveFocus() } }

    // ── top-left: the date ──
    Label {
        x: root.margin; y: root.margin - 8
        text: Qt.formatDate(root.model.now, "dddd, d MMMM")
        size: 18
        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
    }
    // ── top-right: sleep / restart / power ──
    Row {
        visible: root.showControls
        anchors.right: parent.right; anchors.rightMargin: root.margin - 8
        y: root.margin - 14
        spacing: 4
        Repeater {
            model: [{ g: "󰤄", a: "suspend" }, { g: "󰜉", a: "reboot" }, { g: "󰐥", a: "poweroff", danger: true }]
            Rectangle {
                required property var modelData
                width: 46; height: 40; radius: Tokens.rSm
                color: pma.containsMouse ? Tokens.alpha(modelData.danger ? Colors.error : Colors.surfaceFg, modelData.danger ? 0.15 : 0.10) : "transparent"
                Behavior on color { ColorAnimation { duration: 160 } }
                Glyph { anchors.centerIn: parent; text: parent.modelData.g; size: 22
                    color: pma.containsMouse ? (parent.modelData.danger ? Colors.error : Colors.surfaceFg) : Colors.surfaceVariantFg }
                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.model.power(parent.modelData.a) }
            }
        }
    }
    // ── bottom: the hint ──
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: root.margin
        text: root.greeter ? "Press any key to log in" : "Press any key to unlock"
        size: 13; dim: true
        opacity: 1 - root.q
    }
    // ── centre, idle: the clock ──
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.q * root.clockLift
        opacity: 1 - root.q
        visible: root.q < 0.999
        spacing: -60
        Label { text: Qt.formatTime(root.model.now, "HH"); size: 140; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
        Label { text: Qt.formatTime(root.model.now, "mm"); size: 140; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
    }
    // ── centre, form: name, the input, a status line ──
    ColumnLayout {
        id: form
        visible: root.showControls && root.q > 0.001
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - root.q) * root.formDrop
        opacity: root.q
        enabled: root.q > 0.999
        spacing: 14
        // the user: a drop-up when there is a choice
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            Revealer {
                open: root.model.userListOpen
                Layout.alignment: Qt.AlignHCenter
                Rectangle {
                    implicitWidth: userList.implicitWidth + 12; implicitHeight: userList.implicitHeight + 12
                    radius: Tokens.rMd; color: Tokens.alpha(Colors.surfaceContainer, 0.85)
                    Column { id: userList; anchors.centerIn: parent; spacing: 0
                        Repeater { model: root.model.users
                            Rectangle { required property string modelData; required property int index
                                width: Math.max(160, ul.implicitWidth + 24); height: 30; radius: Tokens.rSm
                                color: uma.containsMouse ? Tokens.alpha(Colors.surfaceFg, 0.10) : "transparent"
                                Label { id: ul; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData; size: 14; color: index === root.model.userIndex ? Colors.primary : Colors.surfaceFg }
                                MouseArea { id: uma; anchors.fill: parent; hoverEnabled: true; onClicked: { root.model.userIndex = index; root.model.userListOpen = false; pw.forceActiveFocus() } } } }
                    }
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: userLabel.implicitWidth + 20; implicitHeight: 32; radius: Tokens.rSm
                color: uma2.containsMouse && root.model.users.length > 1 ? Tokens.alpha(Colors.surfaceFg, 0.10) : "transparent"
                Label { id: userLabel; anchors.centerIn: parent; text: "󰀄  " + (root.model.users[root.model.userIndex] || "") + (root.model.users.length > 1 ? "  󰅃" : ""); size: 15; color: uma2.containsMouse ? Colors.surfaceFg : Colors.surfaceVariantFg }
                MouseArea { id: uma2; anchors.fill: parent; hoverEnabled: true; enabled: root.model.users.length > 1; onClicked: root.model.userListOpen = !root.model.userListOpen }
            }
        }
        // the pill
        Rectangle {
            id: pill
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 300; implicitHeight: 44
            radius: Tokens.rPill
            color: Tokens.alpha(Colors.surfaceContainer, 0.85)
            border.width: 2
            border.color: root.model.status.length ? Colors.error : Colors.primary
            Behavior on border.color { ColorAnimation { duration: 160 } }
            TextInput {
                id: pw
                anchors { left: parent.left; right: enter.left; top: parent.top; bottom: parent.bottom; leftMargin: 20 }
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.family: Tokens.fontFamily; font.bold: true; font.pixelSize: 16; font.letterSpacing: 3
                color: root.model.busy ? Colors.surfaceVariantFg : Colors.surfaceFg
                readOnly: root.model.busy
                cursorDelegate: Rectangle { width: 2; color: Colors.surfaceFg; visible: pw.cursorVisible }
                text: root.model.password
                onTextChanged: if (text !== root.model.password) { root.model.password = text; root.model.touch() }
                onAccepted: root.model.submit()
            }
            Rectangle {
                id: enter
                anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 34; radius: Tokens.rPill
                color: ema.containsMouse ? Tokens.alpha(Colors.primary, 0.15) : "transparent"
                Glyph { anchors.centerIn: parent; text: root.model.busy ? "󰔟" : "󰌑"; size: 20 }
                MouseArea { id: ema; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.model.submit() }
            }
        }
        Label { Layout.alignment: Qt.AlignHCenter; text: root.model.status.length ? root.model.status : " "; size: 13; color: Colors.error }
    }
    // ── bottom-left: the session (greeter only) ──
    ColumnLayout {
        visible: root.greeter && root.showControls
        x: root.margin - 8; anchors.bottom: parent.bottom; anchors.bottomMargin: root.margin - 8
        opacity: root.q
        enabled: root.q > 0.999
        spacing: 4
        Revealer {
            open: root.model.sessionListOpen
            Rectangle {
                implicitWidth: sessList.implicitWidth + 12; implicitHeight: sessList.implicitHeight + 12
                radius: Tokens.rMd; color: Tokens.alpha(Colors.surfaceContainer, 0.85)
                Column { id: sessList; anchors.centerIn: parent
                    Repeater { model: root.model.sessions
                        Rectangle { required property var modelData; required property int index
                            width: Math.max(180, sl.implicitWidth + 24); height: 30; radius: Tokens.rSm
                            color: sma.containsMouse ? Tokens.alpha(Colors.surfaceFg, 0.10) : "transparent"
                            Label { id: sl; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; size: 13; color: index === root.model.sessionIndex ? Colors.primary : Colors.surfaceFg }
                            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: { root.model.sessionIndex = index; root.model.sessionListOpen = false; pw.forceActiveFocus() } } } }
                }
            }
        }
        Rectangle {
            implicitWidth: sessLabel.implicitWidth + 24; implicitHeight: 32; radius: Tokens.rSm
            color: sma2.containsMouse && root.model.sessions.length > 1 ? Tokens.alpha(Colors.surfaceFg, 0.10) : "transparent"
            Label { id: sessLabel; anchors.centerIn: parent; text: (root.model.sessions[root.model.sessionIndex] || { name: "" }).name + (root.model.sessions.length > 1 ? "  󰅃" : ""); size: 13; color: sma2.containsMouse ? Colors.surfaceFg : Colors.surfaceVariantFg }
            MouseArea { id: sma2; anchors.fill: parent; hoverEnabled: true; enabled: root.model.sessions.length > 1; onClicked: root.model.sessionListOpen = !root.model.sessionListOpen }
        }
    }
}
