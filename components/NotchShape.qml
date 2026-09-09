import QtQuick
import QtQuick.Shapes
import "../core"

// The morphing silhouette.
//
//   t = 0   → a lip hanging from the top bezel, fused to it by two concave
//             "ears". Small bottom corners, no top corners.
//   t = 1   → a rounded sheet that has lifted a few px off the edge, all
//             corners rounded, ears gone.
//
// Deliberately flat: one fully opaque fill, no stroke, no border, no blur.
// At rest the notch is pure black so it reads as part of the display bezel
// rather than a card floating on top of it.
//
// ── why the radii are budgeted, not constant ────────────────────────────
// Every radius here is clamped against the *current* body size and against
// the other radii sharing the same edge. That is not defensive polish: with
// fixed radii, a body only 8 px tall asks for a 17 px bottom corner and a
// 15 px ear, the arcs run past each other, and the SVG path folds inside
// out — which is exactly what made the ears read as two separate blobs
// drifting away from the middle during a peek. Budgeting the radii means
// the silhouette is a single well-formed outline at *every* size, so the
// whole notch scales as one object.
//
// ── why the cross-fade is scheduled the way it is ───────────────────────
// Two SVG paths (attached / detached) are cross-faded because no single
// path expresses both a concave ear and a lifted rounded top. The swap is
// only invisible if the two paths are geometrically identical while it
// happens, so the ear is fully closed before `blend` starts and the lift
// and top corners only begin after it ends.
Item {
    id: shape

    property real bodyWidth: Config.peekWidth
    property real bodyHeight: Config.peekHeight
    property real t: 0

    property color fillColor: Theme.notchFill

    readonly property real _maxW: Config.expandedWidth + Config.earRadius * 2
    // Intrinsic size — the consumer (Notch) sizes its container to this, so
    // do NOT anchor-fill this item from outside or the bindings go circular.
    width: _maxW
    // Headroom for the lift plus the peek's downward overshoot.
    height: Config.expandedGap * t + bodyHeight + 14

    // ── morph schedule ──────────────────────────────────────────
    // Strictly ordered: ears close → paths swap → panel lifts and opens its
    // top corners. Nothing overlaps, so nothing can ghost.
    readonly property real _earT: 1 - Config.ramp(0, Config.earEnd, t)
    readonly property real _blend: Config.smooth(Config.earEnd, Config.blendEnd, t)
    readonly property real _liftT: Config.smooth(Config.earEnd, Config.liftEnd, t)

    // ── interpolated geometry, all mutually budgeted ────────────
    readonly property real _h: Math.max(0, bodyHeight)
    readonly property real _halfW: Math.max(0, bodyWidth / 2)
    readonly property real _bl: (_maxW - bodyWidth) / 2
    readonly property real _br: _bl + bodyWidth
    readonly property real _topY: Config.expandedGap * _liftT

    // Bottom corner first — it defines the notch's own character, so it gets
    // the height budget before the ear does.
    readonly property real _bR: Math.min(Config.mix(Config.peekCorner, Config.expandedCorner, _liftT), _h / 2, _halfW)
    // Top corner only opens once the shape has detached.
    readonly property real _tR: Math.min(Config.expandedCorner * _liftT, Math.max(0, _h - _bR), _halfW)
    // The ear lives on whatever vertical room the bottom corner left over, so
    // it can never reach below the body's own bottom edge.
    readonly property real _ear: Math.min(Config.earRadius * _earT, Math.max(0, _h - _bR), _halfW)

    // Attached: fused to the bezel by two concave ears, square across the top.
    function _attached() {
        var bl = _bl, br = _br, ear = _ear, bR = _bR, topY = _topY;
        var bot = topY + _h;
        var sideTop = ear + topY;
        var d = "M " + (bl - ear) + " 0 ";
        d += "A " + ear + " " + ear + " 0 0 1 " + bl + " " + sideTop + " ";
        d += "L " + bl + " " + (bot - bR) + " ";
        d += "A " + bR + " " + bR + " 0 0 0 " + (bl + bR) + " " + bot + " ";
        d += "L " + (br - bR) + " " + bot + " ";
        d += "A " + bR + " " + bR + " 0 0 0 " + br + " " + (bot - bR) + " ";
        d += "L " + br + " " + sideTop + " ";
        d += "A " + ear + " " + ear + " 0 0 1 " + (br + ear) + " 0 ";
        d += "L " + (bl - ear) + " 0 Z";
        return d;
    }

    // Detached: a free-floating rounded sheet.
    function _detached() {
        var bl = _bl, br = _br, bR = _bR, topY = _topY, tR = _tR;
        var bot = topY + _h;
        var d = "M " + (bl + tR) + " " + topY + " ";
        d += "L " + (br - tR) + " " + topY + " ";
        d += "A " + tR + " " + tR + " 0 0 1 " + br + " " + (topY + tR) + " ";
        d += "L " + br + " " + (bot - bR) + " ";
        d += "A " + bR + " " + bR + " 0 0 1 " + (br - bR) + " " + bot + " ";
        d += "L " + (bl + bR) + " " + bot + " ";
        d += "A " + bR + " " + bR + " 0 0 1 " + bl + " " + (bot - bR) + " ";
        d += "L " + bl + " " + (topY + tR) + " ";
        d += "A " + tR + " " + tR + " 0 0 1 " + (bl + tR) + " " + topY + " Z";
        return d;
    }

    // Nothing to draw below a sub-pixel body — and a degenerate path is the
    // one thing a Shape renders as garbage rather than as nothing.
    visible: _h > 0.6 && bodyWidth > 1

    Shape {
        anchors.fill: parent
        visible: shape._blend < 0.999
        opacity: 1 - shape._blend
        ShapePath {
            strokeWidth: 0
            fillColor: shape.fillColor
            PathSvg { path: shape._attached() }
        }
    }
    Shape {
        anchors.fill: parent
        visible: shape._blend > 0.001
        opacity: shape._blend
        ShapePath {
            strokeWidth: 0
            fillColor: shape.fillColor
            PathSvg { path: shape._detached() }
        }
    }
}
