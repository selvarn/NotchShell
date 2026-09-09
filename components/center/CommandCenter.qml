import QtQuick
import "../../core"
import "../../services"
import "../primitives"
import "pages"

// The expanded sheet. It is a single container that *transforms* between
// pages — root and every drill-down live in the same clipped viewport and
// slide past each other, so it always reads as one physical object rather
// than a stack of windows.
//
// `clip` here is what keeps content honest: as the notch grows, the sheet's
// contents are revealed from inside its own bounds instead of spilling out
// of them.
Item {
    id: center

    clip: true

    readonly property real pad: Config.pagePad
    readonly property real contentWidth: width - pad * 2
    // How far the outgoing page drifts — a parallax nudge, not a full swap.
    readonly property real slide: contentWidth * 0.28

    // The chrome band at the foot of the sheet: the grabber pill, the gap
    // above it and the sheet's own bottom padding. The notch takes its drag
    // zone from this, so the band the user grabs is exactly the band that
    // holds no controls.
    readonly property real _grabberBlock: 4 + Config.gap
    readonly property real grabZone: pad + _grabberBlock

    readonly property real _activeHeight: {
        switch (CenterNav.page) {
        case "network":
            return networkPage.implicitHeight;
        case "audio":
            return audioPage.implicitHeight;
        case "nightlight":
            return nightLightPage.implicitHeight;
        case "notifications":
            return notificationsPage.implicitHeight;
        case "power":
            return powerPage.implicitHeight;
        case "calendar":
            return calendarPage.implicitHeight;
        default:
            return rootPage.implicitHeight;
        }
    }

    // Drives the notch's expanded height, so changing page resizes the sheet.
    implicitHeight: pad * 2 + _grabberBlock + _activeHeight

    Behavior on implicitHeight {
        NumberAnimation { duration: Config.pageDur; easing.type: Config.easePage }
    }

    // Services only poll while the sheet is actually on screen, and the
    // sheet always reopens at its root page.
    Connections {
        target: UiState
        function onCenterVisibleChanged() {
            Net.polling = UiState.centerVisible;
            Notify.polling = UiState.centerVisible;
            Media.polling = UiState.centerVisible;
            if (UiState.centerVisible)
                resetNav.stop();
            else
                resetNav.restart();
        }
    }
    Timer {
        id: resetNav
        interval: Config.dismissDur + 60
        onTriggered: CenterNav.reset()
    }

    // The sheet is drawn over the window-wide click-away scrim, but drawing
    // over a MouseArea is not the same as covering it: a press that lands on
    // the panel's own background — the padding between cards, the gap beside
    // the transport, a control that happens to be disabled — fell straight
    // through and dismissed the Command Center. One swallowing surface,
    // declared first so every real control sits above it, keeps clicks
    // inside the sheet; the scrim still closes it from anywhere outside.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    // Pull grabber — pinned to the sheet's bottom edge, never slides with
    // the pages. It lives down here rather than up top because the sheet
    // hangs from the top bezel: a handle at its head leaves nowhere to pull
    // *to*, the pointer runs out of screen before the gesture registers.
    // At the foot it travels with the growing edge, and closing is a pull
    // back up into the bezel with the whole screen to do it in.
    Rectangle {
        id: grabber
        y: center.height - center.pad - height
        anchors.horizontalCenter: parent.horizontalCenter
        width: 34
        height: 4
        radius: 2
        color: Theme.textFaint
        opacity: Config.stagger(0, UiState.expandFraction)
    }

    Item {
        id: viewport
        x: center.pad
        y: center.pad
        width: center.contentWidth
        height: Math.max(0, center.height - y - center.grabZone)
        clip: true

        RootPage {
            id: rootPage
            width: viewport.width
            x: CenterNav.atRoot ? 0 : -center.slide
            opacity: CenterNav.atRoot ? 1 : 0
            visible: opacity > 0.01

            Behavior on x {
                NumberAnimation { duration: Config.pageDur; easing.type: Config.easePage }
            }
            Behavior on opacity {
                NumberAnimation { duration: Config.pageDur * 0.7; easing.type: Config.easeFade }
            }
        }

        // Every drill-down page shares one sliding host, so root↔detail is a
        // single movement no matter which page you opened.
        Item {
            id: detailHost
            width: viewport.width
            height: viewport.height
            x: CenterNav.atRoot ? center.slide : 0
            opacity: CenterNav.atRoot ? 0 : 1
            visible: opacity > 0.01

            Behavior on x {
                NumberAnimation { duration: Config.pageDur; easing.type: Config.easePage }
            }
            Behavior on opacity {
                NumberAnimation { duration: Config.pageDur * 0.7; easing.type: Config.easeFade }
            }

            NetworkPage {
                id: networkPage
                width: parent.width
                visible: CenterNav.page === "network"
            }
            AudioPage {
                id: audioPage
                width: parent.width
                visible: CenterNav.page === "audio"
            }
            NightLightPage {
                id: nightLightPage
                width: parent.width
                visible: CenterNav.page === "nightlight"
            }
            NotificationsPage {
                id: notificationsPage
                width: parent.width
                visible: CenterNav.page === "notifications"
            }
            PowerPage {
                id: powerPage
                width: parent.width
                visible: CenterNav.page === "power"
            }
            CalendarPage {
                id: calendarPage
                width: parent.width
                visible: CenterNav.page === "calendar"
            }
        }
    }
}
