import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../core"

// One full-screen overlay per monitor. It never draws a background and its
// input region is masked down to exactly what's interactive right now:
//   • a thin hover strip at the top edge (always)
//   • the notch body (whenever the peek is visible)
//   • the whole screen (only while the Command Center is open, for the
//     click-away scrim)
PanelWindow {
    id: win

    property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notch"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
        Region { item: hoverStrip }
        Region { item: notch.inputArea }
        Region { item: scrim }
    }

    // Drives the peek in/out. The two surfaces are reported separately, not
    // OR'd: only the strip may *start* a hover peek, while the body keeps an
    // already-started one alive as the pointer moves down into the notch.
    // See UiState's hover latch for why.
    // One pointer, one UiState, but one window per monitor — so a window only
    // reports hover it actually owns, and never clears a neighbour's.
    readonly property bool stripHovered: stripHover.hovered
    readonly property bool bodyHovered: notch.bodyHovered
    property bool _ownsStrip: false
    property bool _ownsBody: false

    onStripHoveredChanged: {
        if (stripHovered) {
            _ownsStrip = true;
            UiState.setStripHover(true);
        } else if (_ownsStrip) {
            _ownsStrip = false;
            UiState.setStripHover(false);
        }
    }
    onBodyHoveredChanged: {
        if (bodyHovered) {
            _ownsBody = true;
            UiState.setBodyHover(true);
        } else if (_ownsBody) {
            _ownsBody = false;
            UiState.setBodyHover(false);
        }
    }

    Item {
        id: hoverStrip
        width: Config.hoverStripWidth
        height: Config.hoverStripHeight
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        HoverHandler { id: stripHover }
    }

    // Click-away scrim. Zero-size (contributes nothing to the mask) unless
    // the Command Center is open.
    MouseArea {
        id: scrim
        x: 0
        y: 0
        width: UiState.centerVisible ? parent.width : 0
        height: UiState.centerVisible ? parent.height : 0
        enabled: UiState.centerVisible
        onClicked: UiState.dismiss()

        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            opacity: UiState.expandFraction
        }
    }

    Notch {
        id: notch
        anchors.fill: parent
    }
}
