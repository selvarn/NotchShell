pragma Singleton

import QtQuick
import "."

// Every geometry, timing and motion number the shell runs on.
//
// This is NOT the config. `shell.conf` is — a dozen questions in plain text,
// read and validated by core/Settings.qml. What lives here is the answer to
// all the questions that were never asked: the shape schedule of the notch,
// the tone of every animation curve, the sizes that hold the layout
// together. They are derived from the config where the config has an
// opinion, and fixed where it does not.
//
// So: a person tuning the shell edits shell.conf. Someone changing what the
// shell *is* edits this. Components read neither literal nor config — only
// the tokens below.
QtObject {
    id: cfg

    // Every animation in the shell is scaled by one number the user owns.
    readonly property real _speed: Settings.animationSpeed
    function _dur(ms) {
        return Math.max(1, Math.round(ms * _speed));
    }

    // Roundness, likewise: one decision, applied to cards and the sheet in
    // full and to the notch's own silhouette at half strength — its corners
    // are part of how the shape reads as a bezel, not a taste setting.
    readonly property real _r: Settings.rounding
    readonly property real _rNotch: 1 + (Settings.rounding - 1) * 0.5

    // ─────────────────────────────────────────────────────────────
    //  Geometry — peek ("the notch")
    // ─────────────────────────────────────────────────────────────

    readonly property real peekWidth: Settings.notchWidth
    readonly property real peekHeight: Settings.notchHeight

    // Concave "ears" that fuse the peek into the top bezel. Only present
    // while the shape is still attached to the edge (morphs away on drag).
    readonly property real earRadius: 15 * _rNotch
    // Never more than half the height: past that the arcs meet and the lip
    // stops being a rectangle with rounded ends.
    readonly property real peekCorner: Math.min(peekHeight / 2, 17 * _rNotch)

    // Shape-morph schedule, expressed on the notch's detach parameter t.
    // The ear must be fully gone *before* the attached→detached path swap
    // begins, otherwise the two silhouettes differ during the cross-fade and
    // the ears visibly ghost away as separate objects. Everything after
    // `earEnd` (lift off the bezel, top corners opening) is therefore
    // scheduled strictly after the ears have closed.
    readonly property real earEnd: 0.10
    readonly property real blendEnd: 0.17
    readonly property real liftEnd: 0.55

    // Downward overshoot of the peek reveal, as a fraction. Purely a shaping
    // term on the notch's own geometry — it never touches `progress`, so it
    // can never push the shape across a phase boundary.
    readonly property real peekBounce: 1.6
    readonly property int bounceEaseDur: _dur(130)

    // How much a transient status is allowed to widen the peek.
    readonly property real transientMaxWidth: 320

    // Invisible hover affordance at the very top of the screen. Kept no
    // wider than the notch's own hit area so the peek never appears for a
    // pointer that is nowhere near it.
    readonly property real hoverStripHeight: 6
    readonly property real hoverStripWidth: 240

    // ─────────────────────────────────────────────────────────────
    //  Geometry — Command Center
    // ─────────────────────────────────────────────────────────────

    readonly property real expandedWidth: Settings.panelWidth
    readonly property real expandedMinHeight: 180
    readonly property real expandedCorner: 34 * _r
    // Gap between the top screen edge and the lifted panel.
    readonly property real expandedGap: 12

    readonly property real pagePad: 18
    readonly property real gap: 12

    // Soft-UI radii. No glass; depth comes from tone steps and roundness.
    readonly property real rSm: 12 * _r
    readonly property real rMd: 18 * _r
    readonly property real rLg: 24 * _r

    readonly property real clockTileSize: 132
    readonly property real tileHeight: 62
    readonly property real sliderHeight: 40
    readonly property real pageHeaderHeight: 34

    // ─────────────────────────────────────────────────────────────
    //  Geometry — launchers
    // ─────────────────────────────────────────────────────────────

    // The launcher is a centred sheet, not part of the notch: it needs the
    // keyboard, and the notch window deliberately never takes focus.
    readonly property real launcherWidth: Settings.launcherWidth
    readonly property real launcherSearchHeight: 58
    readonly property real launcherRowHeight: 46

    // BOTH launchers are exactly this size, always — they are two faces of one
    // sheet, and a sheet that resized as you tabbed between them (or as a
    // query narrowed the list) would read as two different windows taking
    // turns. Sized for the smaller of the two, the wallpaper picker, and
    // rounded to a whole number of app rows so the list never comes to rest
    // halfway through one.
    readonly property int launcherRows: Settings.launcherRows
    readonly property real launcherBodyHeight: launcherRows * launcherRowHeight + 12

    // A name column narrow enough to stay a column, leaving the rest to the
    // preview.
    readonly property real launcherWallListWidth: 186

    // Scroll rail: a hairline that says how much more there is, wide enough
    // in its hit area to actually grab.
    readonly property real railWidth: 4
    readonly property real railHitWidth: 14
    readonly property real railMinThumb: 26
    // Sits a little above the true centre — an empty field at dead centre
    // reads as lower than centre once the results push the sheet downward.
    readonly property real launcherRise: 60

    readonly property int launcherOpenDur: _dur(200)
    readonly property int launcherCloseDur: _dur(140)

    // Applications the launcher must never show — `launcher.hidden_apps`.
    readonly property var hiddenApps: Settings.hiddenApps

    // ═════════════════════════════════════════════════════════════
    //  System integration — the parts that touch YOUR machine
    // ═════════════════════════════════════════════════════════════
    //
    // All of it comes from the `system` block of shell.conf, which is where
    // it is documented. Nothing is decided here: these are pass-throughs, so
    // that the rest of the shell keeps reading one place for its tokens.

    // A terminal for a `Terminal=true` .desktop entry; the entry's own argv
    // is appended to this.
    readonly property var terminalCommand: Settings.terminal

    // "auto" | "native" | "lua" — see services/Hypr.qml.
    readonly property string hyprlandDispatch: Settings.hyprlandDispatch

    // Keyboard layouts in the order `kb_layout` lists them.
    readonly property var layoutCodes: Settings.keyboardLayouts

    // Where the picker looks, relative to $HOME, and what it counts as an
    // image.
    readonly property string wallpaperDir: Settings.wallpaperDir
    readonly property var wallpaperFormats: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]

    // Putting the picture up, and recolouring the shell from it. Two jobs,
    // separate on purpose so either can be swapped or switched off. `%f` is
    // the image; `%x` / `%y` are where on screen the choice was made.
    readonly property string wallpaperCommand: Settings.wallpaperCommand
    // Theme.qml watches ~/.cache/wal/colors.json, so whatever this writes
    // re-themes the running shell on its own.
    readonly property string paletteCommand: Settings.paletteCommand

    // ─────────────────────────────────────────────────────────────
    //  Drag
    // ─────────────────────────────────────────────────────────────

    // Pointer travel (px) that corresponds to a full peek→expanded pull.
    readonly property real dragSpan: 260
    // On release: past this fraction of the pull we snap open, else back.
    readonly property real dragCommitFraction: 0.4
    // Rubber-band resistance once the pointer goes past either end.
    readonly property real dragOvershootResist: 0.35

    // ─────────────────────────────────────────────────────────────
    //  Timing (ms)
    // ─────────────────────────────────────────────────────────────

    readonly property int peekDur: _dur(210)      // hidden ↔ peek
    readonly property int expandDur: _dur(360)    // peek ↔ expanded
    readonly property int collapseDur: _dur(280)  // expanded → peek
    readonly property int dismissDur: _dur(380)   // expanded → hidden, in one go
    readonly property int snapDur: _dur(250)      // post-drag settle
    readonly property int widthDur: _dur(210)     // transient re-sizing the peek
    readonly property int contentFadeDur: _dur(150)
    readonly property int pageDur: _dur(280)      // Command Center page transition

    // How long a status lingers — `notch.status_time`. Not scaled by the
    // animation speed: it is a reading time, not a movement.
    readonly property int transientTtl: Settings.statusTime

    // ─────────────────────────────────────────────────────────────
    //  Media
    // ─────────────────────────────────────────────────────────────

    // A seek is a round trip, and a browser answers it in two parts: it
    // takes the new position long before it has a picture to show there.
    // The requested spot is held over the player's own clock until that
    // clock arrives at it (within `seekConfirmSlack`), and no longer than
    // `seekConfirmMs` in case the player never takes the seek at all.
    readonly property int seekConfirmMs: 6000
    readonly property real seekConfirmSlack: 2.5   // s

    // A player that has not announced a length is asked for one directly,
    // this often and no more times than this, then left alone — a live
    // stream has no length to give and must not be interrogated forever.
    readonly property int lengthAskMs: 800
    readonly property int lengthAskTries: 10

    // Answers that differ by less than this are the same answer.
    readonly property real posRewindSlack: 0.6     // s
    // A clock that ran ahead of its picture corrects itself backwards once
    // the picture arrives. For this long after a scrub the readout waits
    // that correction out where it stands rather than replaying the same
    // seconds in reverse — but only this far back and for this long. Outside
    // the window, and beyond these limits, a step backwards is somebody
    // seeking in the player itself and is followed at once.
    readonly property int posSettleMs: 20000
    readonly property real posCatchUpMax: 20       // s
    readonly property int posCatchUpMs: 15000

    // ─────────────────────────────────────────────────────────────
    //  Motion — shared easing so nothing invents its own curve
    // ─────────────────────────────────────────────────────────────

    // The `progress` driver is deliberately MONOTONE — no OutBack, no spring.
    // An overshoot there would push progress past `peekStop` and silently flip
    // the notch into its detached topology mid-peek. Physicality is added back
    // by `overshoot()` on the notch's own geometry instead.
    readonly property int easeEnter: Easing.OutCubic
    readonly property int easeExit: Easing.OutCubic
    readonly property int easeSnap: Easing.OutQuint
    readonly property int easeFade: Easing.OutQuad
    readonly property int easePage: Easing.OutExpo
    // Dismissal travels the WHOLE track in one movement, which is a different
    // problem from the short moves above. A front-loaded curve (OutQuint) tips
    // most of the distance into the first few frames and then leaves a thin
    // lip crawling into the bezel; symmetric easing keeps it reading as one
    // object being drawn back in, and lands it cleanly with nothing trailing.
    readonly property int easeDismiss: Easing.InOutCubic

    // Spring used for physically-moving indicators (segmented control).
    readonly property real springStiffness: 5.0
    readonly property real springDamping: 0.5
    readonly property real springMass: 0.9

    // ─────────────────────────────────────────────────────────────
    //  Icon layout
    // ─────────────────────────────────────────────────────────────

    // Every glyph is drawn inside a square box of `size * iconBoxScale`.
    // Horizontal centring is measured per glyph from its ink rect (see
    // Icon.qml); vertically the line box is already a faithful proxy for
    // these glyphs, so this global nudge exists only to correct the whole
    // set at once should a different icon font ever be used. Measured at 0.
    readonly property real iconBoxScale: 1.7
    readonly property real iconOpticalY: 0

    // ─────────────────────────────────────────────────────────────
    //  Misc
    // ─────────────────────────────────────────────────────────────

    readonly property bool debug: false

    // Where the peek rests on the unified 0..1 "open" track. Below this the
    // shape is retracting toward hidden; above it, expanding toward the
    // Command Center. Kept small so the peek reads as a thin lip.
    readonly property real peekStop: 0.16

    // ─────────────────────────────────────────────────────────────
    //  Tiny math helpers (shared so bindings stay readable)
    // ─────────────────────────────────────────────────────────────
    function clamp(x, lo, hi) {
        return x < lo ? lo : x > hi ? hi : x;
    }
    function mix(a, b, t) {
        return a + (b - a) * t;
    }
    // Smooth 0→1 ramp as x goes edge0→edge1 (Hermite).
    function smooth(edge0, edge1, x) {
        var u = clamp((x - edge0) / (edge1 - edge0), 0, 1);
        return u * u * (3 - 2 * u);
    }
    // Linear 0→1 ramp, clamped.
    function ramp(edge0, edge1, x) {
        return clamp((x - edge0) / (edge1 - edge0), 0, 1);
    }
    // OutBack as a plain function, so a *dimension* can overshoot without the
    // phase parameter that drives it ever leaving [0, 1]. s = 0 is identity.
    function overshoot(x, s) {
        if (s <= 0)
            return x;
        var u = x - 1;
        return 1 + (s + 1) * u * u * u + s * u * u;
    }
    // Staggered reveal ramp for the i-th row of Command Center content.
    function stagger(i, x) {
        return smooth(0.22 + i * 0.05, 0.72 + i * 0.05, x);
    }
}
