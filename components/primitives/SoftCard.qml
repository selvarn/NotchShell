import QtQuick
import "../.."

// A soft-UI surface: a quiet tone step above the panel, generously rounded,
// no glass and no hard border. Depth is tone + roundness, not translucency.
Rectangle {
    id: card

    property bool raised: false
    property bool sunken: false
    property bool hovered: false
    property bool pressed: false
    // Only for surfaces that would otherwise dissolve into the wallpaper.
    property bool hairline: false

    radius: Config.rMd
    antialiasing: true

    color: sunken ? Theme.sunken : raised ? Theme.raised : pressed ? Theme.surfaceActive : hovered ? Theme.surfaceHover : Theme.surface

    border.width: hairline ? 1 : 0
    border.color: Theme.border

    // Pressing a card settles it very slightly — a physical nudge, not a
    // bounce.
    scale: pressed ? 0.985 : 1.0

    Behavior on color {
        ColorAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
    }
    Behavior on scale {
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }
}
