import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../services"
import "../primitives"

// The launchers. One sheet, two contents.
//
// This is a separate window from the notch, and it has to be: it takes
// exclusive keyboard focus, and NotchWindow is built never to take focus at
// all (`WlrKeyboardFocus.None`) so that the notch can sit over a full-screen
// app without swallowing a keystroke. Keeping them apart means the notch's
// input model stays exactly as simple as it was.
//
// It is still the same material as the Command Center — panel tone, soft
// cards, the same radii and the same accent — so it reads as another face of
// the same shell rather than a separate program.
PanelWindow {
    id: win

    // Open where the user is looking. Hyprland's own collections populate a
    // second or two after startup, so the first screen is the fallback rather
    // than an error.
    screen: {
        var name = Hypr.focusedMonitorName;
        var list = Quickshell.screens;
        if (name.length)
            for (var i = 0; i < list.length; i++)
                if (list[i].name === name)
                    return list[i];
        return list.length ? list[0] : null;
    }

    // One value drives the whole entrance, and the window outlives it by
    // exactly as long as the exit takes — so closing is animated rather than
    // a surface blinking out of existence.
    property real anim: Launcher.open ? 1 : 0
    Behavior on anim {
        NumberAnimation {
            duration: Launcher.open ? Config.launcherOpenDur : Config.launcherCloseDur
            easing.type: Config.easeEnter
        }
    }

    visible: Launcher.open || anim > 0.001

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    // Only while it is actually open: a layer surface that asks for exclusive
    // focus is holding the keyboard away from every real window, and this one
    // must never do that a moment longer than it is on screen.
    WlrLayershell.keyboardFocus: Launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Rescan on the way in. Opening the launcher is the one moment the answer
    // is certain to be wanted, and it costs a single `cat` of ~45 small files.
    Connections {
        target: Launcher
        function onModeChanged() {
            if (!Launcher.open)
                return;
            // Two sheets at once is never what was meant. The launcher is the
            // newer intent, so the Command Center gets out of the way.
            if (UiState.centerVisible)
                UiState.dismiss();
            if (Launcher.mode === "apps")
                Apps.refresh();
            input.text = "";
            input.forceActiveFocus();
        }
    }

    onVisibleChanged: if (visible)
        input.forceActiveFocus()

    // ── click-away ──────────────────────────────────────────────
    // Catches the click, dims nothing. The sheet is opaque and small; a scrim
    // over the whole screen was doing nothing for legibility and quite a lot
    // to whatever you were looking at a moment ago.
    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.hide()
    }

    // ── the sheet ───────────────────────────────────────────────
    Item {
        id: sheet

        // One size, both faces, never resized by what is in it. See
        // Config.launcherBodyHeight.
        width: Config.launcherWidth
        height: Config.launcherSearchHeight + 1 + Config.launcherBodyHeight

        // Whole pixels, both axes. A sheet at a half-pixel offset does not
        // just soften its text: it lands the rounded-corner clip between
        // samples, which is what left the wallpaper preview with two square
        // corners and two round ones.
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2 - Config.launcherRise)

        opacity: win.anim
        // A small rise and a small scale, and nothing else. The sheet is
        // appearing in place, not travelling from anywhere.
        scale: 0.97 + 0.03 * win.anim
        transform: Translate {
            y: (1 - win.anim) * 10
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: Config.rLg
            antialiasing: true
            color: Theme.panel
            clip: true

            // ── search row ──────────────────────────────────────
            Item {
                id: searchRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Config.launcherSearchHeight

                Icon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: Launcher.mode === "walls" ? Icons.image : Icons.search
                    size: 15
                    color: Theme.textMuted
                }

                TextInput {
                    id: input
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: modeHint.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textPrimary
                    font.family: Theme.fontSans
                    font.pixelSize: 16
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    clip: true

                    onTextChanged: Launcher.query = text

                    cursorDelegate: Rectangle {
                        width: 2
                        radius: 1
                        color: Theme.accent
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: input.activeFocus
                            NumberAnimation { to: 0; duration: 480; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1; duration: 480; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: input.text.length === 0
                        text: Launcher.mode === "walls" ? "Search wallpapers" : "Search applications"
                        color: Theme.textFaint
                        font: input.font
                    }

                    Keys.onEscapePressed: Launcher.hide()
                    Keys.onUpPressed: Launcher.move(-1)
                    Keys.onDownPressed: Launcher.move(1)
                    Keys.onTabPressed: Launcher.toggleMode()
                    Keys.onBacktabPressed: Launcher.toggleMode()

                    // Left and Right are the carousel, unconditionally: the
                    // two launchers are one ring, and either arrow steps to
                    // the other face. An earlier version only switched when
                    // the caret had nowhere further to go, so that arrows
                    // could still edit the query — but switching clears the
                    // query anyway, which made the same key do one thing on
                    // an empty field and another on a full one for no gain.
                    // Editing keeps Home, End, Backspace and the pointer.
                    Keys.onLeftPressed: Launcher.toggleMode()
                    Keys.onRightPressed: Launcher.toggleMode()
                    Keys.onReturnPressed: win.activate()
                    Keys.onEnterPressed: win.activate()
                }

                // What Tab will give you. A hint that is also the control, so
                // the shortcut is discoverable without a legend along the
                // bottom of the sheet.
                Item {
                    id: modeHint
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: hintRow.implicitWidth + 18
                    height: 26

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: hintMa.containsMouse ? Theme.surfaceHover : Theme.surface
                        Behavior on color {
                            ColorAnimation { duration: Config.contentFadeDur }
                        }
                    }

                    Row {
                        id: hintRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⇥"
                            color: Theme.textFaint
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Launcher.mode === "walls" ? "Apps" : "Wallpapers"
                            color: Theme.textMuted
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: hintMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Launcher.toggleMode();
                            input.forceActiveFocus();
                        }
                    }
                }
            }

            Rectangle {
                id: rule
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchRow.bottom
                height: 1
                color: Theme.separator
            }

            // ── body ────────────────────────────────────────────
            Item {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: rule.bottom
                anchors.bottom: parent.bottom
                clip: true

                AppResults {
                    id: appView
                    anchors.fill: parent
                    active: Launcher.mode === "apps"
                    opacity: active ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        NumberAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
                    }
                }

                WallpaperResults {
                    id: wallView
                    anchors.fill: parent
                    active: Launcher.mode === "walls"
                    screenHeight: win.height
                    opacity: active ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        NumberAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
                    }
                }
            }
        }
    }

    function activate() {
        if (Launcher.mode === "walls")
            wallView.activate();
        else
            appView.activate();
    }
}
