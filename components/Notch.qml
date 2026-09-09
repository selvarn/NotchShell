import QtQuick
import "../"
import "../core"
import "peek"
import "transient"
import "center"

// The one notch. Always in the scene; every dimension is a continuous
// function of UiState.progress, so hidden → peek → expanded (and back, and
// interrupted mid-drag) is a single uninterrupted morph. Content layers
// cross-fade; they are never created or destroyed.
//
// ── one curve, one object ───────────────────────────────────────────────
// Width and height are both shaped by `reveal` — the *same* function of the
// *same* phase parameter. Nothing here runs its own Behavior on a geometric
// dimension, because two dimensions on two animators is precisely how the
// silhouette comes apart: they finish at different times and the notch reads
// as a middle plus two ears rather than one object.
//
// The single exception is `_peekWidth`, which is a genuinely separate event
// (a transient arriving wants a wider notch); it is disabled while the notch
// is off-screen so it can only ever animate a width the user can see.
Item {
    id: notch

    readonly property real pf: UiState.peekFraction     // 0..1 over the peek
    readonly property real ef: UiState.expandFraction   // 0..1 over the expansion
    readonly property bool hasTransient: UiState.current !== null

    property alias inputArea: hitArea
    readonly property bool bodyHovered: bodyHover.hovered

    // ── the reveal curve ────────────────────────────────────────
    // A settle overshoot applied to the peek phase as a pure function. It
    // shapes geometry only — `progress` itself stays monotone, so this can
    // never push the shape across the peek/expand boundary and flip its
    // topology. Retracting and dragging ease the bounce out instead of
    // switching it off, so an interrupted reveal never jumps.
    property real _bounce: (UiState.wantHidden || UiState.dragging) ? 0 : Config.peekBounce
    Behavior on _bounce {
        NumberAnimation { duration: Config.bounceEaseDur; easing.type: Config.easeExit }
    }
    readonly property real reveal: Config.overshoot(pf, _bounce)

    // ── body size ───────────────────────────────────────────────
    // Peek width follows the transient content; springs back to the resting
    // width when there is nothing to show.
    property real _peekWidth: hasTransient ? Config.clamp(transientLayer.desiredWidth, Config.peekWidth, Config.transientMaxWidth) : Config.peekWidth
    Behavior on _peekWidth {
        // Off-screen width changes snap: animating a width nobody can see
        // only means the notch emerges at the wrong size.
        enabled: notch.pf > 0.05 && !UiState.dragging
        NumberAnimation { duration: Config.widthDur; easing.type: Config.easeSnap }
    }

    readonly property real _expandedHeight: Math.max(Config.expandedMinHeight, commandCenter.implicitHeight)

    readonly property real bodyWidth: {
        var base = Config.mix(_peekWidth, Config.expandedWidth, ef);
        // Slight narrow-in while still emerging from the edge — same curve as
        // the height, so the whole silhouette scales as one piece.
        return base * (0.86 + 0.14 * reveal);
    }
    readonly property real bodyHeight: Config.mix(Config.peekHeight * reveal, _expandedHeight, ef)
    readonly property real detach: ef

    anchors.fill: parent
    visible: UiState.peekVisible

    // ── the drawn notch (shape + content) ───────────────────────
    Item {
        id: visual
        width: shape.width
        height: shape.height
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        // Deliberately no opacity ramp. The notch is opaque black emerging
        // from an opaque black bezel: growth *is* the reveal, and a fade on
        // top of it would be a second, differently-timed animation of the
        // same event — the thing this file exists to avoid.

        NotchShape {
            id: shape
            // Intrinsic size drives `visual`; must not anchor-fill it.
            bodyWidth: notch.bodyWidth
            bodyHeight: notch.bodyHeight
            t: notch.detach
            // Bezel-black through the whole peek, warming to the sheet's
            // panel tone only once the Command Center is clearly open.
            fillColor: Theme.blend(Theme.notchFill, Theme.panel, Config.smooth(0.35, 0.85, notch.ef))
        }

        // Content, sized to the body. Peek content is guarded by opacity
        // ramps; the Command Center clips itself (see CommandCenter.qml).
        Item {
            id: body
            x: (parent.width - notch.bodyWidth) / 2
            y: Config.expandedGap * Config.smooth(Config.earEnd, Config.liftEnd, notch.detach)
            width: notch.bodyWidth
            height: notch.bodyHeight

            // Content shows only once the shape has emerged (pf) and clears
            // quickly the moment expansion starts (ef), so peek/transient
            // content never lingers into the Command Center transition.
            readonly property real _peekReveal: Config.ramp(0.45, 0.95, notch.pf) * (1 - Config.ramp(0, 0.1, notch.ef))

            PeekContent {
                id: peekContent
                anchors.fill: parent
                opacity: body._peekReveal * (notch.hasTransient ? 0 : 1)
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
                }
            }

            TransientLayer {
                id: transientLayer
                anchors.fill: parent
                opacity: body._peekReveal * (notch.hasTransient ? 1 : 0)
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
                }
            }

            // Fills the body exactly, so its own clip is the sheet's edge:
            // contents are revealed inside the growing panel and can never
            // spill past it.
            CommandCenter {
                id: commandCenter
                width: parent.width
                height: parent.height
                opacity: Config.smooth(0.10, 0.45, notch.ef)
                visible: opacity > 0.01
            }
        }
    }

    // ── drag + tap + hover ──────────────────────────────────────
    // Grab zone: the whole peek (generously padded so a 34 px lip is still
    // catchable), or the sheet's foot once expanded — the band that holds
    // the grabber and no controls, so the Command Center body stays
    // interactive. Collapses to nothing when the notch is fully hidden —
    // otherwise it stays in the window's input mask and silently eats
    // clicks meant for whatever is underneath.
    //
    // Both forms end at the same edge and grow upward from it, so the switch
    // between them never moves the zone out from under a pointer that is
    // mid-drag: at the crossover the sheet is barely taller than the peek
    // and the two bands are all but the same strip.
    Item {
        id: hitArea

        readonly property bool live: UiState.peekVisible
        // Just below the body while peeking (a catchable lip), the body's
        // own bottom edge once the sheet is open (past it is click-away).
        readonly property real grabBottom: visual.y + body.y + body.height + (UiState.centerVisible ? 0 : 22)

        x: visual.x + body.x + body.width / 2 - width / 2
        y: live ? Math.max(0, grabBottom - height) : 0
        width: live ? Math.max(Config.hoverStripWidth, body.width + 32) : 0
        height: !live ? 0 : UiState.centerVisible ? commandCenter.grabZone : grabBottom
        z: 10

        DragHandler {
            id: pull
            target: null
            xAxis.enabled: false
            yAxis.enabled: true
            onActiveChanged: {
                if (active)
                    UiState.dragBegin();
                else
                    UiState.dragEnd(pull.centroid.velocity.y);
            }
            onActiveTranslationChanged: {
                if (active)
                    UiState.dragMove(activeTranslation.y);
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                if (UiState.wantExpanded)
                    UiState.dismiss();
                else
                    UiState.toExpanded();
            }
        }

        HoverHandler {
            id: bodyHover
        }
    }
}
