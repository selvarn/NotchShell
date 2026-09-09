pragma Singleton

import QtQuick
import "."

// The single source of truth for what the shell is doing.
//
// One continuous driver — `progress` ∈ [0, 1] — governs the whole motion:
//
//     0 ............ peekStop ............................ 1
//   hidden           peek (notch)              expanded (Command Center)
//
// Every visual (shape height, corner radius, ear depth, content opacity,
// scrim) is a pure function of `progress`, so states can never visually
// desync and a drag can interrupt an animation at any point.
//
// `progress` is a PHASE, not a spring. Its Behavior is deliberately monotone:
// an overshoot here would carry progress past `peekStop`, which silently
// changes the notch's topology (ears begin morphing away, the panel starts
// lifting) in the middle of what should be a plain peek. Where motion wants
// physicality, the component shapes its own geometry — see Notch.reveal.
//
// Two behaviours share the peek and must not be conflated:
//   • the TIME peek is cursor-driven — it appears on hover and leaves the
//     instant the pointer does, with no timeout;
//   • a TRANSIENT status (workspace, layout, volume, …) appears on its own,
//     owns the notch for its TTL, and then leaves.
QtObject {
    id: state

    // ── intent: what we are heading toward ───────────────────────
    // "hidden" | "peek" | "expanded"
    property string intent: "hidden"
    readonly property bool wantHidden: intent === "hidden"
    readonly property bool wantPeek: intent === "peek"
    readonly property bool wantExpanded: intent === "expanded"

    // Opening the sheet retires whatever the notch was showing. A transient
    // that was live when the sheet opened has been invisible ever since, and
    // letting it survive its TTL under the panel would only mean `dismiss()`
    // handing the peek back to a status the user has already read past.
    // Covers the drag commit too, which sets `intent` directly.
    onIntentChanged: if (intent === "expanded")
                         _dropTransients()

    // ── the driver ──────────────────────────────────────────────
    property real progress: 0
    property bool dragging: false
    // internal: selects the Behavior's timing/curve for the current move
    property string _mode: "peek"

    Behavior on progress {
        enabled: !state.dragging
        NumberAnimation {
            duration: state._mode === "snap" ? Config.snapDur : state._mode === "expand" ? Config.expandDur : state._mode === "dismiss" ? Config.dismissDur : state._mode === "collapse" ? Config.collapseDur : Config.peekDur
            easing.type: state._mode === "snap" ? Config.easeSnap : state._mode === "dismiss" ? Config.easeDismiss : (state._mode === "collapse" || state._mode === "retract") ? Config.easeExit : Config.easeEnter
        }
    }

    // ── derived, clamped fractions for components ────────────────
    readonly property real peekStop: Config.peekStop
    readonly property real peekFraction: Config.clamp(progress / peekStop, 0, 1)
    readonly property real expandFraction: Config.clamp((progress - peekStop) / (1 - peekStop), 0, 1)
    readonly property bool peekVisible: progress > 0.002
    readonly property bool centerVisible: progress > peekStop + 0.015

    // True from the moment the sheet is committed to opening until it has
    // visibly closed again. The Command Center is one focused surface: a
    // status popping the notch out from under it — or sitting in the queue
    // waiting to pop out the instant it closes — reads as a second window
    // arguing with the first.
    readonly property bool centerOpen: intent === "expanded" || centerVisible

    // The sheet still owns the notch on its way out. A status — or a hover —
    // answered in the middle of the collapse stops the panel at peek size and
    // leaves it there, which reads as the Command Center *turning into* a
    // notch rather than closing. Nothing may raise the notch until the shape
    // is actually gone.
    readonly property bool centerLeaving: intent === "hidden" && progress > peekStop

    // ── the peek always belongs to someone ──────────────────────
    // A peek exists for exactly two reasons: the pointer is on the notch, or
    // a transient status is being shown. Nothing else may leave the shell
    // sitting at `peek`, because nothing else has a way back out —
    // `_syncHover` retires a peek only on a hovering true→false *edge*, and
    // a peek that was never hover-driven has no such edge coming. That is
    // how the Command Center used to end its life as a notch that hung on
    // screen forever: some path (a stray re-grab mid-collapse, a status that
    // slipped in during the dismissal) parked `intent` at "peek" with no
    // hover and no transient, and there it stayed.
    //
    // Every such path is a bug and is fixed at its source; this is the net
    // underneath them. It fires while the shape is still on its way down, so
    // the correction is invisible — the collapse simply continues to hidden
    // instead of stopping halfway.
    readonly property bool peekOrphaned: intent === "peek" && !hovering && !dragging && current === null
    onPeekOrphanedChanged: if (peekOrphaned)
                               _orphanGuard.restart()

    property Timer _orphanGuard: Timer {
        // A beat rather than zero: state lands in pieces (a transient is
        // assigned the frame before the peek it raises), and retiring inside
        // that gap would fight whatever is still settling.
        interval: 50
        onTriggered: if (state.peekOrphaned)
                         state.toHidden()
    }

    // ── transient status queue ──────────────────────────────────
    // current: { kind: string, data: object, priority: int, ttl: int } | null
    property var current: null
    property var _queue: []

    property Timer _ttlTimer: Timer {
        interval: Config.transientTtl
        onTriggered: state._advance()
    }

    // ── hover ───────────────────────────────────────────────────
    // Two separate surfaces report hover: the thin strip at the very top of
    // the screen, and the notch body itself. Only the STRIP may *start* a
    // hover session; the body may only sustain one.
    //
    // Without that latch, a transient that grows the notch under a resting
    // pointer captures it — the body reports hover the user never performed,
    // and the notch stays out after the status expires. The two lifecycles
    // (cursor-driven peek, self-driven transient) must not leak into each
    // other, and this is where they would.
    property bool hovering: false
    property bool _stripHover: false
    property bool _bodyHover: false
    property bool _hoverLatch: false
    // Set when the sheet was closed by a gesture *on the notch* — a pull on
    // the grabber, a tap. That pointer is spent: without this it is sitting
    // on the hover strip the moment the shape clears it, and the peek the
    // user just put away pops straight back up under the cursor.
    //
    // It is spent only until it moves, though. Demanding that the pointer
    // leave the strip and come back means waving the mouse up and down to
    // get a peek that should already be there — so a single pixel of travel
    // is enough (see pointerMoved()). Every other way of closing — a click
    // away, a keybind — leaves hover alone entirely.
    property bool _hoverBlocked: false
    // The same closing gesture, for the drag handler rather than for hover:
    // Qt can hand the grab back while the shape is still retiring under a
    // finger that never lifted. Unlike the hover block this one is not
    // cleared by movement — the movement is the tail of that very gesture.
    property bool _closedByGesture: false

    function setStripHover(h) {
        _stripHover = h;
        if (h && !_hoverBlocked)
            _hoverLatch = true;
        _syncHover();
    }

    function setBodyHover(h) {
        _bodyHover = h;
        _syncHover();
    }

    function _syncHover() {
        if (!_stripHover && !_bodyHover) {
            _hoverLatch = false;
            _hoverBlocked = false;
        }
        var h = _hoverLatch && (_stripHover || _bodyHover);
        if (h === hovering)
            return;
        hovering = h;
        if (h) {
            _grant();
            return;
        }
        // Pointer left. The time peek is purely cursor-driven, so it goes
        // away at once — no timeout. A live transient keeps the notch until
        // its TTL expires; the Command Center ignores hover entirely.
        if (intent === "expanded" || dragging || current)
            return;
        toHidden();
    }

    // Hand the notch to the pointer, if the pointer is entitled to it.
    //
    // Deferred, never dropped: while the Command Center is on screen — open
    // or collapsing — the notch is the sheet's, so a hover that arrives then
    // is remembered rather than answered. The instant the shape is gone the
    // same hover is granted, so closing the sheet and reaching for the top
    // edge gives a peek immediately, with no waving the mouse off the strip
    // and back to wake it up.
    function _grant() {
        if (_hoverBlocked || intent !== "hidden" || peekVisible)
            return;
        if (_hoverLatch && _stripHover)
            toPeek();
    }

    // Called on every pointer movement over the hover strip. Movement is
    // what makes a spent cursor a fresh approach again — one pixel, no
    // round trip off the strip.
    function pointerMoved() {
        if (!_hoverBlocked)
            return;
        _hoverBlocked = false;
        if (_stripHover)
            _hoverLatch = true;
        _syncHover();
        _grant();
    }

    // The shape has finished retiring: the gesture that closed it is over
    // (nothing is left to re-grab), and whoever was waiting for the notch
    // gets it now. This is what turns "no peek while the sheet is leaving"
    // into a deferral instead of a refusal.
    onPeekVisibleChanged: {
        if (peekVisible)
            return;
        _closedByGesture = false;
        _grant();
    }

    // ── public actions ──────────────────────────────────────────
    function toHidden() {
        intent = "hidden";
        _animate(0, progress > peekStop + 0.02 ? "collapse" : "retract");
    }

    function toPeek() {
        intent = "peek";
        _animate(peekStop, progress > peekStop + 0.02 ? "collapse" : "peek");
    }

    function toExpanded() {
        intent = "expanded";
        _animate(1, "expand");
    }

    // Closing the Command Center is NOT "go back to peek".
    //
    // The peek is cursor-driven: it exists because the pointer is on the
    // notch. By the time the sheet is dismissed the pointer is usually
    // nowhere near it — and the pointer-left event that would have retired
    // the peek already happened while the sheet was open, where it was
    // correctly ignored (the Command Center does not care about hover). So
    // nothing was ever going to retire that peek afterwards; it simply sat
    // there until the notch was touched again.
    //
    // Dismissal therefore goes all the way out in one movement, and blocks
    // the hover strip until the pointer has actually left, so closing the
    // sheet cannot summon the very thing it just closed.
    function dismiss(byPointer) {
        _leave("dismiss", byPointer === true);
    }

    // The whole of dismissal apart from its timing. A drag that lets the
    // sheet go shares every part of this — including the hover block, which
    // matters *more* for a drag: the pointer is necessarily still on the
    // notch at release, so without it the hover strip answers immediately
    // and re-summons the peek the release just closed.
    function _leave(mode, byPointer) {
        // A live transient still owns the notch and has its own TTL; let it
        // finish in the peek rather than cutting it off.
        if (current) {
            toPeek();
            return;
        }
        // Only a gesture on the notch spends the pointer that made it. Hover
        // itself is left exactly as it is: the cursor really is where it is,
        // and if it is on the strip when the shape finishes leaving it has
        // earned its peek (see _grant).
        _hoverBlocked = byPointer === true;
        _closedByGesture = byPointer === true;
        intent = "hidden";
        _animate(0, mode);
    }

    function toggleExpanded() {
        if (intent === "expanded")
            dismiss();
        else
            toExpanded();
    }

    // Raise a transient status inside the notch. Same-kind calls coalesce
    // and refresh the timer instead of stacking.
    function notify(kind, data, opts) {
        // Nothing pops out over the Command Center. Statuses are dropped,
        // not deferred: a volume OSD — usually raised by the sheet's own
        // slider — arriving seconds after the sheet closes is stale noise,
        // and everything a transient reports is already on the sheet.
        if (centerOpen || centerLeaving)
            return;

        opts = opts || {};
        var item = {
            kind: kind,
            data: data || ({}),
            priority: opts.priority || 0,
            ttl: opts.ttl || Config.transientTtl
        };

        if (current && current.kind === kind) {
            current = item;
            _ttlTimer.interval = item.ttl;
            _ttlTimer.restart();
            if (intent === "hidden")
                toPeek();
            return;
        }

        _queue = _queue.filter(function (q) {
            return q.kind !== kind;
        });
        _queue.push(item);
        _queue.sort(function (a, b) {
            return b.priority - a.priority;
        });

        if (!current || item.priority > current.priority)
            _advance();
    }

    function clearTransient() {
        _dropTransients();
        _retireIfIdle();
    }

    // Empty the queue without touching `intent`. Unlike clearTransient(),
    // this runs *while* the sheet is taking the notch over, so it must not
    // try to retire a notch that something else now owns.
    function _dropTransients() {
        _queue = [];
        current = null;
        _ttlTimer.stop();
    }

    // ── drag interaction ────────────────────────────────────────
    property real _dragStart: 0
    // Whether this drag picked the notch up with the sheet already open.
    // Letting go of an open sheet is a dismissal, not a return to peek —
    // see dragEnd().
    property bool _dragFromCenter: false

    function dragBegin() {
        // The notch is already retiring under a pointer that never lifted.
        // Qt hands the handler back mid-collapse — the grab is cancelled as
        // the shape shrinks past the pointer, then re-taken while the button
        // is still down — and that second activation is not a new gesture:
        // it is the tail of the one the shell has already answered. Acting
        // on it re-opens a sheet the user just closed, or (worse) releases
        // into a peek nobody asked for. `_hoverBlocked` is precisely the
        // "dismissed out from under this pointer" flag, and it clears the
        // moment the pointer actually leaves.
        if (_closedByGesture && intent === "hidden")
            return;

        dragging = true;
        _dragStart = progress;
        _dragFromCenter = centerOpen;
    }

    // pullPx: downward pointer travel since press (negative = upward)
    function dragMove(pullPx) {
        if (!dragging)
            return;
        var raw = _dragStart + (pullPx / Config.dragSpan) * (1 - peekStop);
        if (raw > 1)
            raw = 1 + (raw - 1) * Config.dragOvershootResist;
        else if (raw < 0)
            raw = raw * Config.dragOvershootResist;
        progress = Config.clamp(raw, -0.06, 1.1);
    }

    // velocityPx: vertical pointer velocity at release, px/s (down positive)
    function dragEnd(velocityPx) {
        if (!dragging)
            return;
        dragging = false;
        var v = (velocityPx / Config.dragSpan) * (1 - peekStop); // progress/s
        var projected = progress + v * 0.11;
        var commit = peekStop + Config.dragCommitFraction * (1 - peekStop);

        if (projected >= commit) {
            intent = "expanded";
            _animate(1, "snap");
            return;
        }

        // Two ways a release goes all the way out rather than settling at
        // the peek:
        //
        //   • it let the sheet go. Closing the Command Center is a
        //     dismissal, and a dismissal never stops at the peek — the same
        //     reasoning as dismiss(), only the timing differs.
        //   • nothing owns a peek here. The pointer is not hovering and no
        //     transient is live, so the notch would be left out with nothing
        //     coming to take it back in.
        if (_dragFromCenter || !(hovering || current)) {
            _leave("snap", true);
            return;
        }

        intent = "peek";
        _animate(peekStop, "snap");
    }

    // ── internals ───────────────────────────────────────────────
    function _animate(target, mode) {
        _mode = mode;
        progress = target;
    }

    // Retract only if nothing else still wants the notch. Checking `dragging`
    // matters: a TTL expiring mid-drag must not yank the shape out from under
    // the pointer.
    function _retireIfIdle() {
        if (intent === "peek" && !hovering && !dragging && !current)
            toHidden();
    }

    function _advance() {
        if (_queue.length === 0) {
            current = null;
            _ttlTimer.stop();
            _retireIfIdle();
            return;
        }
        current = _queue.shift();
        _ttlTimer.interval = current.ttl;
        _ttlTimer.restart();
        if (intent === "hidden")
            toPeek();
    }
}
