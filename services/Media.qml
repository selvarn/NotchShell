pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import ".."

// The one MPRIS player the Command Center shows.
//
// Two things here exist because real players lie, and both were symptoms the
// card showed rather than bugs in the card:
//
//   • WHICH player is shown is latched, not re-derived every frame. Several
//     players report Paused for a frame or two while they answer a seek, and
//     a "whatever is playing, else the first on the bus" binding answers that
//     by handing the card to something else — so scrubbing Telegram with a
//     paused YouTube tab behind it flashed the YouTube player and back.
//   • HOW LONG the track is, is remembered per track. Firefox drops
//     `mpris:length` out of its metadata on a seek and only puts it back at
//     the next play/pause, which is exactly "the progress bar disappears
//     until I pause and play again".
//
// Both are the same rule: a player that stops answering a question is not the
// same as a player that has answered "nothing".
QtObject {
    id: media

    // Set true by the Command Center while it is visible. Position is the
    // only thing here that has to be pulled, and it is only ever *shown*
    // inside the Command Center — so outside it the poll is pure waste, and
    // one more chance to touch a player whose service has already gone.
    property bool polling: false

    readonly property var players: Mpris.players ? Mpris.players.values : []

    // ── which player ────────────────────────────────────────────
    //
    // Assigned, never bound: `_repick` reads the current choice to decide
    // whether to keep it, and a binding that reads itself is a loop.
    property var player: null

    // A player that has just started playing while another is on screen has
    // to hold that claim for a moment before it gets the card. That settle is
    // the whole flicker fix: a seek makes the *current* player report Paused
    // briefly, and without the wait the card would jump away and back inside
    // the same gesture.
    property var _handoverTo: null

    property Timer _handover: Timer {
        interval: 350
        onTriggered: {
            var c = media._handoverTo;
            media._handoverTo = null;
            // Re-ask every part of the question — the situation that asked
            // for this handover may have evaporated while we waited.
            if (c && media.players.indexOf(c) !== -1 && c.isPlaying && (!media.player || !media.player.isPlaying))
                media.player = c;
        }
    }

    function _repick() {
        var ps = players;
        if (!ps || ps.length === 0) {
            player = null;
            _handoverTo = null;
            _handover.stop();
            return;
        }

        // Still showing a player that is on the bus? Then it keeps the card
        // unless something else has a better claim.
        if (player && ps.indexOf(player) !== -1) {
            if (player.isPlaying) {
                // Nothing outranks the player that is actually playing.
                _handoverTo = null;
                _handover.stop();
                return;
            }
            for (var i = 0; i < ps.length; i++) {
                if (ps[i] !== player && ps[i].isPlaying) {
                    if (_handoverTo !== ps[i]) {
                        _handoverTo = ps[i];
                        _handover.restart();
                    }
                    return;
                }
            }
            // Nobody is playing: the paused player on screen stays on screen.
            _handoverTo = null;
            _handover.stop();
            return;
        }

        // No player, or the one we had has left the bus — take the best now.
        _handoverTo = null;
        _handover.stop();
        for (var j = 0; j < ps.length; j++) {
            if (ps[j].isPlaying) {
                player = ps[j];
                return;
            }
        }
        player = ps[0];
    }

    readonly property bool available: player !== null

    readonly property string title: available && player.trackTitle ? player.trackTitle : ""
    readonly property string artist: available && player.trackArtist ? player.trackArtist : ""
    readonly property string artUrl: available && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property string appName: available && player.identity ? player.identity : ""

    readonly property bool playing: available && player.isPlaying
    readonly property bool canGoNext: available && player.canGoNext
    readonly property bool canGoPrevious: available && player.canGoPrevious
    readonly property bool canToggle: available && player.canTogglePlaying

    // ── how long the track is ───────────────────────────────────
    //
    // What the player is saying right now. Zero means "not telling", which is
    // not the same as "no length" — see `length`.
    readonly property real rawLength: (available && player.lengthSupported && player.length > 0) ? player.length : 0

    // Identity of the track being played, as far as the shell can tell. Only
    // a change here is allowed to throw the remembered length away.
    readonly property string trackKey: available ? (player.identity + "\u0000" + player.trackTitle + "\u0000" + player.trackArtist) : ""

    property string _lengthKey: ""
    property real length: 0

    function _refreshLength() {
        if (trackKey !== _lengthKey) {
            // Genuinely a different track: whatever the player says now is
            // the truth, including "nothing yet".
            _lengthKey = trackKey;
            length = rawLength;
            return;
        }
        // Same track. A fresh answer replaces the old one; silence does not.
        if (rawLength > 0)
            length = rawLength;
    }

    // Whether there is a timeline to draw at all. A live stream never reports
    // a length, and the card shows transport only rather than a bar that can
    // never fill.
    readonly property bool hasLength: length > 0
    readonly property bool canSeek: available && player.canSeek && hasLength

    // ── position ────────────────────────────────────────────────
    //
    // MPRIS does not push position, and neither does Quickshell — but its
    // MprisPlayer *does* advance the value locally between the D-Bus updates
    // it gets, so `player.position` is already smooth. It is a pull, though:
    // nothing emits a change, so the number only moves when something reads
    // it. That is the whole trick here — read it at frame rate while the
    // sheet is open and the bar sweeps; read it once a second (or, as
    // before, never, because nothing ever set `polling`) and it steps or
    // sits at zero.
    property real position: 0
    readonly property real progress: hasLength ? Config.clamp(position / length, 0, 1) : 0

    // A seek is a round trip: until the player answers, it still reports the
    // old position. Hold the requested one over the top for a moment so the
    // bar stays where it was dropped instead of snapping back and then
    // jumping forward again.
    property real _seekHold: -1

    property Timer _seekGrace: Timer {
        interval: 700
        onTriggered: media._seekHold = -1
    }

    property Timer _poll: Timer {
        // Frame rate, not once a second: this is a local read, not a bus
        // call, so the cost is a property write and the gain is a bar that
        // actually moves.
        interval: 33
        repeat: true
        // Not gated on `available`: this tick is also where the choice of
        // player and the remembered length are re-checked, and neither has a
        // change signal of its own to hang off.
        running: media.polling
        triggeredOnStart: true
        onTriggered: {
            media._repick();
            media._refreshLength();
            media._sync();
        }
    }

    function _sync() {
        // Guarded rather than optimistic: a player that has just quit is
        // briefly still in the list, and reading `position` off it is a DBus
        // call to a service that is no longer there.
        if (!available || !player.positionSupported) {
            media.position = 0;
            return;
        }
        var t = media._seekHold >= 0 ? media._seekHold : player.position;
        // A player whose clock has drifted past the end would otherwise
        // print a readout longer than the track.
        media.position = hasLength ? Config.clamp(t, 0, length) : Math.max(0, t);
    }

    // ── transport ───────────────────────────────────────────────
    function toggle() {
        if (canToggle)
            player.togglePlaying();
    }
    function next() {
        if (canGoNext)
            player.next();
    }
    function previous() {
        if (canGoPrevious)
            player.previous();
    }

    function seekFraction(f) {
        if (!canSeek)
            return;
        var t = Config.clamp(f, 0, 1) * length;
        media._seekHold = t;
        media.position = t;
        media._seekGrace.restart();
        media.player.position = t;
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0 || !isFinite(seconds))
            return "0:00";
        var t = Math.floor(seconds);
        var h = Math.floor(t / 3600);
        var m = Math.floor(t / 60) % 60;
        var s = t % 60;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Players appearing and disappearing has to be answered at once, even
    // with the sheet shut — otherwise `player` is left pointing at a
    // destroyed object and every binding that reads it starts throwing.
    property Connections _onPlayers: Connections {
        target: media
        function onPlayersChanged() {
            media._repick();
        }
    }

    // Switching player or track invalidates the position, any seek we were
    // still holding over the top of it, and the remembered length.
    property Connections _onTrack: Connections {
        target: media

        function onPlayerChanged() {
            media._reset();
        }
        function onTrackKeyChanged() {
            media._reset();
        }
        function onRawLengthChanged() {
            media._refreshLength();
        }
    }

    function _reset() {
        media._seekHold = -1;
        media._seekGrace.stop();
        media._refreshLength();
        media._sync();
    }

    Component.onCompleted: media._repick()
}
