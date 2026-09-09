import QtQuick
import "../../core"

// A single Nerd Font glyph, optically centred in a predictable square box.
//
// This is an Item, not a bare Text, on purpose. A Text sizes itself to its
// content, so `anchors.centerIn` centres the *line box* of whatever glyph
// happens to be showing — and a line box is as tall as the font's ascent
// plus descent regardless of how much ink the glyph actually puts on screen.
// Every icon therefore ended up centred slightly differently, and swapping a
// glyph (sun → moon, bell → bell-off) nudged it again.
//
// Two separate corrections are needed, and they have different causes:
//
//   • VERTICALLY, the line box is a reliable proxy: these glyphs are drawn
//     centred in the em box, so centring the line box centres the ink.
//   • HORIZONTALLY it is not. The icon font is monospaced, so every glyph is
//     handed the same advance width, but the FontAwesome shapes inside those
//     cells have their own widths and are not centred in them. Centring the
//     advance box therefore leaves the ink off to one side — measurably up
//     to 3 px for the wider glyphs, which is exactly the "icons look a bit
//     crooked" symptom.
//
// So the horizontal offset is *measured*, not guessed: TextMetrics reports
// the glyph's tight ink rect, and the label is shifted by the difference
// between the ink centre and the advance centre. That is one rule for every
// icon in the shell rather than a table of per-glyph nudges, and it keeps
// working for glyphs nobody has audited yet.
Item {
    id: icon

    property string text: ""
    property real size: 15
    property color color: Theme.textPrimary
    // Square bounding box shared by every icon at this size.
    property real box: Math.round(size * Config.iconBoxScale)
    // Escape hatches for the rare glyph the metrics can't speak for (an icon
    // whose ink is deliberately asymmetric, say). Normally left alone.
    property real opticalX: 0
    property real opticalY: Config.iconOpticalY

    implicitWidth: box
    implicitHeight: box
    width: box
    height: box

    TextMetrics {
        id: metrics
        font.family: Theme.fontIcon
        font.pixelSize: icon.size
        text: icon.text
    }

    // How far the glyph's ink sits from the centre of its advance cell.
    // Positive means the ink leans right, so the label is shifted left by it.
    readonly property real _inkOffset: {
        var r = metrics.tightBoundingRect;
        if (!r || r.width <= 0 || metrics.advanceWidth <= 0)
            return 0;
        return (r.x + r.width / 2) - metrics.advanceWidth / 2;
    }

    Text {
        id: label
        width: icon.box
        height: icon.box
        x: -icon._inkOffset + icon.opticalX
        y: icon.opticalY
        text: icon.text
        color: icon.color
        font.family: Theme.fontIcon
        font.pixelSize: icon.size
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        // Distance-field rendering. NativeRendering snaps glyph origins to
        // whole pixels, which is what makes an otherwise-centred icon land
        // half a pixel off in one container and not in the next — and it
        // would quantise away the sub-pixel correction computed above.
        renderType: Text.QtRendering

        Behavior on color {
            ColorAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
        }
    }
}
