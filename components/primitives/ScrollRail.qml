import QtQuick
import "../../core"

// A thin scroll rail for a Flickable: how much more there is, and a handle to
// go there directly.
//
// Two sizes, deliberately. What it *draws* is a hairline, because in a sheet
// this quiet a real scrollbar would be the loudest thing on screen. What it
// *catches* is a much wider strip, because a 4 px drag target is not a target.
// The two are concentric, so the pointer never has to find the hairline.
//
// It appears only when there is something to scroll, and it is bound to the
// Flickable in one direction only: the thumb reads its position from the
// content, and dragging writes `contentY` back. There is no second copy of the
// scroll position to fall out of step.
Item {
    id: rail

    property Flickable flickable: null

    readonly property real _ratio: flickable ? flickable.visibleArea.heightRatio : 1
    readonly property bool scrollable: flickable !== null && _ratio < 0.999

    // How far down the content is, 0..1, independent of how tall it is.
    readonly property real _progress: {
        if (!flickable)
            return 0;
        var span = flickable.contentHeight - flickable.height;
        return span > 0 ? Config.clamp(flickable.contentY / span, 0, 1) : 0;
    }

    readonly property real _travel: Math.max(0, height - thumb.height)
    readonly property bool _live: ma.containsMouse || ma.pressed

    width: Config.railHitWidth

    // Fades rather than disappearing: a rail that pops in and out as a filter
    // narrows the list draws more attention than the rail itself.
    opacity: scrollable ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
    }

    function _scrollTo(y) {
        if (!flickable || _travel <= 0)
            return;
        var frac = Config.clamp(y / _travel, 0, 1);
        flickable.contentY = frac * (flickable.contentHeight - flickable.height);
    }

    // The groove. Barely there — it exists so the thumb has somewhere to be
    // when the list is short.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Config.railWidth
        radius: width / 2
        antialiasing: true
        color: Theme.sunken
    }

    Rectangle {
        id: thumb
        anchors.horizontalCenter: parent.horizontalCenter
        width: Config.railWidth
        // Never shorter than a thumb you can grab, however long the list is.
        height: Math.max(Config.railMinThumb, rail.height * rail._ratio)
        y: rail._travel * rail._progress
        radius: width / 2
        antialiasing: true
        // Legible at rest — the point of the thing is to be read without
        // being looked for — and unmistakable once it is under the pointer.
        color: ma.pressed ? Theme.accent : rail._live ? Theme.textSecondary : Theme.textMuted

        Behavior on color {
            ColorAnimation { duration: 120; easing.type: Config.easeFade }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: rail.scrollable
        cursorShape: Qt.PointingHandCursor

        // Where inside the thumb the drag started, so it does not jump under
        // the pointer on the first press.
        property real grab: 0

        onPressed: mouse => {
            if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height) {
                grab = mouse.y - thumb.y;
                return;
            }
            // Pressed the groove: take the thumb to the pointer and carry on
            // as if the drag had started there.
            grab = thumb.height / 2;
            rail._scrollTo(mouse.y - grab);
        }
        onPositionChanged: mouse => {
            if (pressed)
                rail._scrollTo(mouse.y - grab);
        }
    }
}
