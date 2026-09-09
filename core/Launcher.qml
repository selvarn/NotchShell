pragma Singleton

import QtQuick
import "."

// Which launcher is open, what has been typed into it, and which row is
// selected. Deliberately tiny: the views own their own results, and this owns
// only the state that a keystroke has to change without knowing which view is
// listening.
//
// This is a separate driver from UiState on purpose. The notch's `progress`
// is a continuous *physical* track that a drag can land anywhere on; a
// launcher is open or it is not, and it needs the keyboard, which the notch
// window is built never to take. Folding one into the other would give the
// notch a third topology and a focus mode, and give the launcher a phase
// parameter it has no use for.
QtObject {
    id: launcher

    // "" | "apps" | "walls"
    property string mode: ""
    readonly property bool open: mode !== ""

    property string query: ""

    // Selection, and the row count the active view last reported. The count
    // lives here so that `move` can clamp without asking anyone.
    property int index: 0
    property int count: 0

    // Pressing the same shortcut again closes, which is what every launcher
    // on every desktop does; pressing the other one switches in place.
    function show(m) {
        if (mode === m) {
            hide();
            return;
        }
        mode = m;
        query = "";
        index = 0;
        _disarmHover();
    }

    function hide() {
        mode = "";
        query = "";
        index = 0;
        count = 0;
        _disarmHover();
    }

    // The two launchers are one carousel: with only two faces, "next" and
    // "previous" are the same move, so Left, Right and Tab all land here.
    function toggleMode() {
        show(mode === "apps" ? "walls" : "apps");
    }

    // Stops at the ends rather than wrapping. Holding Down to the bottom of a
    // list and finding yourself back at the top is disorienting: the list has
    // an end, and the selection should say so.
    function move(delta) {
        if (count <= 0) {
            index = 0;
            return;
        }
        index = Config.clamp(index + delta, 0, count - 1);
    }

    // ── hover, gated on the pointer having actually moved ───────────
    //
    // A row also takes the selection when you point at it, so that mouse and
    // keyboard never disagree about what Enter would open. Taken literally
    // ("this row now contains the mouse") that rule fights the keyboard: the
    // arrow keys scroll the list *under* a pointer that is sitting perfectly
    // still, and every row that slides beneath it snatches the selection back
    // — which is what made arrowing through the list feel like it was being
    // pulled sideways. Opening the sheet under the pointer had the same
    // effect, landing the selection on whatever row happened to appear there
    // instead of on the first.
    //
    // So hover is armed by movement, not by arrival: a row claims the
    // selection only when the pointer is somewhere it has not been. The
    // position is compared in *scene* coordinates, because that is the frame
    // the pointer is still in while the row moves through it.
    //
    // The one thing a position alone cannot tell you is whether the sheet
    // just appeared underneath a pointer that was already there, so the gate
    // also stays shut for the length of the entrance — long enough for the
    // rows to be built and to send their arrival events, short enough that it
    // is over before a hand could reach the list.
    property real _hx: -1
    property real _hy: -1
    property bool _hoverArmed: false

    function _disarmHover() {
        _hoverArmed = false;
        _hoverArm.restart();
    }

    property Timer _hoverArm: Timer {
        interval: Config.launcherOpenDur + 60
        onTriggered: launcher._hoverArmed = true
    }

    function hoverAt(i, scenePos) {
        // Still opening: note where the pointer is, so that the first real
        // movement afterwards is measured against it, but let nothing here
        // choose a row.
        if (!_hoverArmed) {
            _hx = scenePos.x;
            _hy = scenePos.y;
            return;
        }
        if (Math.abs(scenePos.x - _hx) < 1 && Math.abs(scenePos.y - _hy) < 1)
            return;
        _hx = scenePos.x;
        _hy = scenePos.y;
        index = i;
    }

    // Typing anything means the old selection is meaningless.
    onQueryChanged: index = 0
}
