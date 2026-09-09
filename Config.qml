pragma Singleton

import QtQuick

// Central tuning surface for the whole shell: geometry, timing and motion
// tokens. Nothing here is a colour (see Theme.qml) and nothing here holds
// runtime state (see core/UiState.qml). Change values here, not in components.
QtObject {
    id: cfg

    // ─────────────────────────────────────────────────────────────
    //  Geometry — peek ("the notch")
    // ─────────────────────────────────────────────────────────────

    readonly property real peekWidth: 172
    readonly property real peekHeight: 34

    // Concave "ears" that fuse the peek into the top bezel. Only present
    // while the shape is still attached to the edge (morphs away on drag).
    readonly property real earRadius: 15
    readonly property real peekCorner: 17

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
    readonly property int bounceEaseDur: 130

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

    readonly property real expandedWidth: 500
    readonly property real expandedMinHeight: 180
    readonly property real expandedCorner: 34
    // Gap between the top screen edge and the lifted panel.
    readonly property real expandedGap: 12

    readonly property real pagePad: 18
    readonly property real gap: 12

    // Soft-UI radii. No glass; depth comes from tone steps and roundness.
    readonly property real rSm: 12
    readonly property real rMd: 18
    readonly property real rLg: 24

    readonly property real clockTileSize: 132
    readonly property real tileHeight: 62
    readonly property real sliderHeight: 40
    readonly property real pageHeaderHeight: 34

    // ─────────────────────────────────────────────────────────────
    //  Geometry — launchers
    // ─────────────────────────────────────────────────────────────

    // The launcher is a centred sheet, not part of the notch: it needs the
    // keyboard, and the notch window deliberately never takes focus.
    readonly property real launcherWidth: 640
    readonly property real launcherSearchHeight: 58
    readonly property real launcherRowHeight: 46

    // BOTH launchers are exactly this size, always — they are two faces of one
    // sheet, and a sheet that resized as you tabbed between them (or as a
    // query narrowed the list) would read as two different windows taking
    // turns. Sized for the smaller of the two, the wallpaper picker, and
    // rounded to a whole number of app rows so the list never comes to rest
    // halfway through one.
    readonly property int launcherRows: 7
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

    readonly property int launcherOpenDur: 200
    readonly property int launcherCloseDur: 140

    // Applications the launcher must never show. Each entry matches either the
    // desktop id — the .desktop filename without its extension, which is often
    // nothing like the visible name ("bssh" is "Avahi SSH Server Browser") —
    // or the name itself, case-insensitively. A trailing `*` matches a prefix,
    // so one line can hide a whole family:
    //
    //     readonly property var hiddenApps: ["Avahi *", "cmake", "htop"]
    //
    // Entries are filtered out of `Apps.all`, so nothing here has to line up
    // with the scan; editing this list is a config edit, which reloads the
    // shell, so the launcher is filtered from the very next time it opens.
    readonly property var hiddenApps: []

    // ═════════════════════════════════════════════════════════════
    //  System integration — the parts that touch YOUR machine
    // ═════════════════════════════════════════════════════════════
    //
    // Everything else in this file is taste. This block is the whole of what
    // the shell hands to the outside world: a few commands, a few paths. It
    // is the first place to look when something in the UI does nothing on a
    // fresh install, and the only block most people need to edit.

    // How a `Terminal=true` .desktop entry gets a terminal. The entry's own
    // argv is appended to this.
    readonly property var terminalCommand: ["kitty", "-e"]

    // ── Hyprland dispatch grammar ────────────────────────────────
    // Vanilla Hyprland takes plain dispatcher syntax (`workspace 3`). A
    // Lua-configured Hyprland — the hyprglass plugin, and anything else that
    // replaces hyprland.conf with hyprland.lua — routes `hyprctl dispatch`
    // through a Lua interpreter instead and wants an expression
    // (`hl.dsp.focus({ workspace = 3 })`). The two are not interchangeable
    // and the wrong one fails without a visible error, which makes this
    // exactly the kind of thing to detect rather than to ask about.
    //
    //   "auto"    probe once at startup and use whichever answers  (default)
    //   "native"  plain dispatchers — vanilla Hyprland
    //   "lua"     Lua expressions — hyprglass and friends
    readonly property string hyprlandDispatch: "auto"

    // Keyboard layouts in the order `kb_layout` lists them, as the two-letter
    // codes the notch shows. Must match your Hyprland input config, because
    // the segmented switch in the layout transient indexes into this.
    readonly property var layoutCodes: ["en", "ru"]

    // ── wallpapers ───────────────────────────────────────────────
    // Where the picker looks, relative to $HOME.
    readonly property string wallpaperDir: "Pictures/Wallpapers"
    readonly property var wallpaperFormats: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]

    // Setting a wallpaper is two jobs, and they are separate on purpose so
    // either can be swapped or switched off. In both templates:
    //
    //     %f   the image path, already shell-quoted
    //     %x   \
    //           > where on screen the choice was made, in the wallpaper
    //     %y   /  daemon's coordinates (origin bottom-left)
    //
    // `%x`/`%y` let the new picture grow out of the thumbnail that was
    // clicked. Drop them and the transition falls back to whatever the
    // daemon does by default.
    //
    // swww users: the drop-in equivalent is
    //     "swww img %f --resize crop --transition-type grow
    //      --transition-pos %x,%y --transition-duration 1.1 --transition-fps 60"
    readonly property string wallpaperCommand: "awww img %f --resize crop --transition-type grow --transition-pos %x,%y --transition-duration 1.1 --transition-fps 60"

    // Regenerating the colour scheme from the new wallpaper. This is what
    // re-themes the shell: Theme.qml watches ~/.cache/wal/colors.json, so the
    // panel, the accent and every tone step follow on their own. Set it to ""
    // to keep a fixed palette and only ever change the picture.
    //
    // `-n` tells pywal not to set the wallpaper itself — that job is already
    // done by the line above, through a daemon pywal knows nothing about.
    readonly property string paletteCommand: "wal --backend schemer2 -n -i %f"

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

    readonly property int peekDur: 210      // hidden ↔ peek
    readonly property int expandDur: 360     // peek ↔ expanded
    readonly property int collapseDur: 280   // expanded → peek
    readonly property int dismissDur: 380    // expanded → hidden, in one go
    readonly property int snapDur: 250       // post-drag settle
    readonly property int widthDur: 210      // transient re-sizing the peek
    readonly property int contentFadeDur: 150
    readonly property int pageDur: 280       // Command Center page transition

    readonly property int transientTtl: 1700 // how long a status lingers

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
