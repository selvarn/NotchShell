pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Night light — a warm tint applied to the whole screen by hyprsunset.
//
// ── why this file looks the way it does ─────────────────────────────────
// hyprsunset (0.4+) keeps a control socket next to the Hyprland instance
// socket, and every setting can be changed on a *running* daemon. That one
// fact is what makes this feel smooth. The previous version had no live
// channel, so a new temperature meant `pkill hyprsunset` and relaunch — and
// for the ~200 ms in between, the compositor had no colour transform at all.
// Every slider settle flashed the screen back to neutral and every toggle
// was a hard snap.
//
// With a live socket the tint becomes an ordinary animatable number:
//
//     enabled / temperature ──▶ target ──(Behavior)──▶ applied ──▶ socket
//
// `applied` is a plain bound property with a Behavior on it, so switching on
// *fades* in, dragging the slider follows the pointer, and interrupting
// either half-way just retargets the same ramp — there is only ever one
// value in motion, and it can be redirected at any point. A pump forwards
// whole kelvin as they pass; nothing else in the shell talks to the daemon.
//
// The daemon is started lazily, on the first switch-on, because it holds the
// compositor's exclusive colour-transform slot for as long as it lives —
// claiming that at login would lock every other gamma tool out of a machine
// whose owner may never turn night light on. Once started it stays, sitting
// at neutral while off, so switching back on is instant.
QtObject {
    id: nl

    // ═══════════════════════════════════════════════════════════
    //  Availability
    // ═══════════════════════════════════════════════════════════

    property bool available: false

    property Process _probe: Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: nl.available = ("" + text).trim() === "yes"
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Desired state
    // ═══════════════════════════════════════════════════════════

    property bool enabled: false
    // Deliberately independent of on/off, so switching off and on again
    // comes back at the warmth you chose.
    property int temperature: 3800

    readonly property int tempMin: 2500
    readonly property int tempMax: 6500
    // The warm end of hyprsunset's own scale is 2500 K; 6500 K is where its
    // colour matrix is (to within a rounding error) the identity, so the top
    // of the slider and "off" are the same picture. That is what lets on/off
    // be a fade along the very same axis the slider moves.
    readonly property int tempNeutral: tempMax

    // On/off is a slow, deliberate cross-fade; following a dragged slider is
    // near-immediate, or the tint lags visibly behind the thumb.
    readonly property int fadeDur: 420
    readonly property int trackDur: 110
    property int _rampDur: fadeDur

    function setEnabled(on) {
        if (enabled === on)
            return;
        _rampDur = fadeDur;
        enabled = on;
        if (on)
            _startDaemon();
    }

    function toggle() {
        setEnabled(!enabled);
    }

    function setTemperature(k) {
        var v = Math.round(Config.clamp(k, tempMin, tempMax));
        if (v === temperature)
            return;
        // Set the ramp *before* the value: the Behavior reads its duration
        // when the binding below re-evaluates, which happens on the very
        // next statement.
        _rampDur = trackDur;
        temperature = v;
    }

    // ═══════════════════════════════════════════════════════════
    //  The one moving value
    // ═══════════════════════════════════════════════════════════

    // Gated on `ready`, which is what keeps the very first switch-on from
    // being a snap. The daemon takes ~300 ms to launch and open its socket;
    // without this the fade would run out entirely while nothing was
    // listening, and the tint would simply appear when the first command
    // finally landed. Held at neutral, the first push *is* neutral — it
    // doubles as the readiness probe — and the ramp starts the moment it is
    // acknowledged.
    readonly property int target: (enabled && ready) ? Config.clamp(temperature, tempMin, tempMax) : tempNeutral

    // Bound, not assigned — so it is always heading for the current target
    // and a change mid-ramp redirects rather than restarts.
    property real applied: nl.target
    Behavior on applied {
        NumberAnimation {
            duration: nl._rampDur
            easing.type: Easing.InOutCubic
        }
    }

    // True while the screen has not caught up with the switch yet, so the
    // tile can say so instead of lying about the new state.
    readonly property bool busy: available && (Math.round(applied) !== target || (enabled && !ready))

    readonly property string summary: !available ? "Unavailable" : enabled ? temperature + "K" : "Off"

    // ═══════════════════════════════════════════════════════════
    //  The daemon
    // ═══════════════════════════════════════════════════════════

    // True once the daemon has acknowledged a command, i.e. it is up and
    // reachable. Nothing else may assume the tint is under our control.
    property bool ready: false

    function _startDaemon() {
        if (!available || _daemon.running)
            return;
        _pushed = -1;
        _daemon.running = true;
    }

    property Process _daemon: Process {
        // A stale hyprsunset from a previous shell run still holds the
        // compositor's colour transform, and only one client may — ours
        // would start and silently do nothing. Claim it, then `exec` so this
        // Process really *is* the daemon: when the shell exits it dies with
        // us and the screen goes back to normal.
        command: ["sh", "-c", "pkill -x hyprsunset 2>/dev/null; sleep 0.2; exec hyprsunset -t " + nl.tempNeutral]
        onExited: {
            nl._pushed = -1;
            nl.ready = false;
            // Only chase it if the tint is still wanted.
            if (nl.enabled)
                nl._respawn.restart();
        }
    }

    property Timer _respawn: Timer {
        interval: 800
        onTriggered: nl._startDaemon()
    }

    // ═══════════════════════════════════════════════════════════
    //  The pump
    // ═══════════════════════════════════════════════════════════

    // Each step of the ramp goes out as a short-lived `hyprctl hyprsunset`
    // call rather than over a control socket this shell keeps open.
    //
    // That is deliberate, and it was measured: hyprsunset serves one client
    // at a time and blocks in a read loop on whoever is connected, so a
    // long-lived connection locks every other tool — `hyprctl` included —
    // out of the daemon for as long as the shell runs. A short call is also
    // the only version that survives the daemon restarting underneath it,
    // and it costs ~9 ms, which is nothing next to a 32 ms frame.

    // Last kelvin actually accepted by the daemon. -1 matches no
    // temperature, so it also means "nothing is known to have landed".
    property int _pushed: -1
    property bool _sending: false
    property int _fails: 0

    property Process _apply: Process {
        onExited: code => {
            nl._sending = false;
            if (code === 0) {
                nl._fails = 0;
                nl.ready = true;
                return;
            }
            // The call applied nothing, so the value recorded as sent is a
            // lie. Forget it — the pump owes the write again. This is also
            // the normal path for the first tick or two after launch, while
            // the daemon is still opening its socket.
            nl._pushed = -1;
            nl._fails++;
        }
    }

    // Runs only while the daemon has not caught up with `applied`, and stops
    // itself the moment it has, so a settled tint costs nothing. Backs right
    // off once calls start failing, so a daemon that never comes up cannot
    // turn into a spin.
    property Timer _pump: Timer {
        interval: nl._fails > 3 ? 400 : 25
        repeat: true
        running: nl._daemon.running && nl._pushed !== Math.round(nl.applied)
        triggeredOnStart: true
        onTriggered: {
            if (nl._sending)
                return;
            var v = Math.round(nl.applied);
            if (v === nl._pushed)
                return;
            nl._pushed = v;
            nl._sending = true;
            // Switched off and settled at the neutral end: hand the
            // compositor a true identity matrix, so "off" is exactly the
            // picture it was before night light ever ran.
            nl._apply.command = (!nl.enabled && v >= nl.tempNeutral) ? ["hyprctl", "hyprsunset", "identity"] : ["hyprctl", "hyprsunset", "temperature", "" + v];
            nl._apply.running = true;
        }
    }
}
