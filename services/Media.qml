pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../core"

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

    // ── asking the player itself ────────────────────────────────
    //
    // Metadata reaches the shell as a *signal*, so a player that learns
    // something and does not announce it leaves the cached copy wrong for as
    // long as it likes. A browser knows a video's duration a moment after
    // playback starts but only republishes metadata at the next play/pause —
    // which is exactly "the bar only turns up once I pause it". The Metadata
    // property itself is right the whole time.
    //
    // So a player that is showing no length gets asked directly, a few times,
    // and is then left alone. Same rule as everything else here: a player
    // that has not said anything is not a player that said "nothing".
    property int _askLeft: 0
    property string _askKey: ""

    property Process _ask: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                var m = ("" + text).match(/'mpris:length':\s*<int64\s+(\d+)>/);
                if (!m)
                    return;
                var secs = parseInt(m[1], 10) / 1000000;
                // The answer belongs to the track it was asked about, and
                // only fills a silence — a player that has since spoken for
                // itself outranks it.
                if (secs > 0 && media._askKey === media.trackKey && media.rawLength <= 0) {
                    media._lengthKey = media.trackKey;
                    media.length = secs;
                    media._askLeft = 0;
                }
            }
        }
        onExited: code => {
            // No gdbus, or a player that will not answer: stop asking.
            if (code !== 0)
                media._askLeft = 0;
        }
    }

    property Timer _askTimer: Timer {
        interval: Config.lengthAskMs
        repeat: true
        triggeredOnStart: true
        // Only while the answer is wanted on screen, and only while there is
        // still a question to ask.
        running: media.polling && media.available && !media.hasLength && media._askLeft > 0
        onTriggered: {
            if (media._ask.running || !media.player.dbusName)
                return;
            media._askLeft -= 1;
            media._askKey = media.trackKey;
            media._ask.command = ["gdbus", "call", "--session", "--dest", media.player.dbusName, "--object-path", "/org/mpris/MediaPlayer2", "--method", "org.freedesktop.DBus.Properties.Get", "org.mpris.MediaPlayer2.Player", "Metadata"];
            media._ask.running = true;
        }
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

    // A seek is a round trip, and a browser answers it in two parts: it
    // accepts the new position long before it has the picture to show
    // there. The requested spot is therefore held over the player's own
    // clock until that clock *arrives* at it — not for a fixed grace, which
    // cannot know how long a buffer takes and let the bar leave the drop
    // point and fall back onto it.
    property real _seekHold: -1
    property real _seekDeadline: 0
    // When the user last put the bar somewhere. A player only runs ahead of
    // its own picture just after being sent there, so that is the only
    // window in which a step backwards is read as a correction rather than
    // as somebody seeking.
    property real _seekAt: -1

    // Set while the readout is waiting for a player whose clock ran ahead of
    // its picture: the instant (ms) after which we stop waiting and take
    // whatever the player says. Zero means nothing is being waited out.
    property real _catchUpUntil: 0

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
            media._catchUpUntil = 0;
            return;
        }

        var now = Date.now();
        var raw = player.position;

        // Has the player arrived where it was sent? Its clock passes through
        // the requested spot and then drifts on from there, so "arrived" is
        // a window rather than equality. Failing that, a player that has
        // plainly not taken the seek does not get to hold the bar forever.
        if (media._seekHold >= 0 && (Math.abs(raw - media._seekHold) <= Config.seekConfirmSlack || now > media._seekDeadline))
            media._seekHold = -1;

        var held = media._seekHold >= 0;
        var t = held ? media._seekHold : raw;
        // A player whose clock has drifted past the end would otherwise
        // print a readout longer than the track.
        t = hasLength ? Config.clamp(t, 0, length) : Math.max(0, t);

        // The readout does not walk backwards on its own. A player that is
        // still fetching the picture keeps counting anyway, then corrects
        // itself the moment the picture lands — so the seconds it invented
        // would be played a second time, in reverse. Wait the correction out
        // where we are instead; the player catches up within its own stall.
        // A jump too far back or a wait too long is not that: it is somebody
        // seeking, and it is followed at once.
        var settling = media._seekAt >= 0 && now - media._seekAt < Config.posSettleMs;
        if (!held && settling && t < media.position - Config.posRewindSlack && media.position - t <= Config.posCatchUpMax) {
            if (media._catchUpUntil === 0)
                media._catchUpUntil = now + Config.posCatchUpMs;
            if (now < media._catchUpUntil)
                return;
        }

        media._catchUpUntil = 0;
        media.position = t;
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
        media._seekDeadline = Date.now() + Config.seekConfirmMs;
        media._seekAt = Date.now();
        media._catchUpUntil = 0;
        media.position = t;
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
        // Someone has opened the sheet: if the length is still missing, it
        // is worth asking again — the run of questions may have been spent
        // minutes ago, on a track that has since learned its own duration.
        function onPollingChanged() {
            if (media.polling && !media.hasLength)
                media._askLeft = Config.lengthAskTries;
        }
    }

    function _reset() {
        media._seekHold = -1;
        media._seekAt = -1;
        media._catchUpUntil = 0;
        // A new track earns a fresh set of questions.
        media._askLeft = Config.lengthAskTries;
        media._refreshLength();
        media._sync();
    }

    Component.onCompleted: media._repick()
}
