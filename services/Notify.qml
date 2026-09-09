pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Do-Not-Disturb and notification history, driven through `dunstctl`.
//
// The shell deliberately does NOT run its own notification server. Only one
// process may own org.freedesktop.Notifications, and on a desktop that runs
// dunst — which this one is built for — claiming it would take that name
// away from dunst and break every application's notifications. So the shell
// reads and drives the server that is already there.
//
// Everything degrades on its own if dunst is absent: `available` goes false
// on the first failed call and the tile stops offering an action.
QtObject {
    id: notify

    // Set true by the Command Center while it is visible.
    property bool polling: false

    property bool available: true
    property bool paused: false
    property int historyCount: 0
    // [{ id, summary, body, app, timestamp }]
    property var history: []

    function setPaused(v) {
        _run(["dunstctl", "set-paused", v ? "true" : "false"]);
    }
    function toggle() {
        setPaused(!paused);
    }
    function clearHistory() {
        _run(["dunstctl", "history-clear"]);
    }

    // Serialised: a second dunstctl call while the first is still running
    // means two results arriving in an order nobody controls, and the UI
    // settling on whichever answered last rather than whichever was asked
    // last.
    property Process _action: Process {
        onExited: {
            notify._actionBusy = false;
            notify._settle.restart();
        }
    }
    property bool _actionBusy: false

    function _run(cmd) {
        if (_actionBusy)
            return;
        _actionBusy = true;
        _action.command = cmd;
        _action.running = true;
        _settle.restart();
    }
    property Timer _settle: Timer {
        interval: 250
        onTriggered: notify.refresh()
    }

    function refresh() {
        // Never while an action is in flight: dunst has not applied it yet,
        // so the answer would be the state we are in the middle of leaving.
        if (_actionBusy)
            return;
        if (!_paused.running)
            _paused.running = true;
        if (!_hist.running)
            _hist.running = true;
    }

    property Timer _tick: Timer {
        interval: 4000
        repeat: true
        running: notify.polling
        triggeredOnStart: true
        onTriggered: notify.refresh()
    }

    property Process _paused: Process {
        command: ["dunstctl", "is-paused"]
        stdout: StdioCollector {
            onStreamFinished: notify.paused = ("" + text).trim() === "true"
        }
        onExited: code => {
            if (code !== 0)
                notify.available = false;
        }
    }

    // dunst emits GVariant-flavoured JSON: every field is {type, data} and
    // the notification array is nested one level deep under `data`.
    property Process _hist: Process {
        command: ["dunstctl", "history"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                try {
                    var doc = JSON.parse("" + text);
                    var list = (doc && doc.data && doc.data[0]) ? doc.data[0] : [];
                    for (var i = 0; i < list.length && i < 40; i++) {
                        var n = list[i];
                        rows.push({
                            id: n.id ? n.id.data : i,
                            summary: n.summary ? n.summary.data : "",
                            body: n.body ? n.body.data : "",
                            app: n.appname ? n.appname.data : "",
                            timestamp: n.timestamp ? n.timestamp.data : 0
                        });
                    }
                } catch (e) {
                    rows = [];
                }
                notify.history = rows;
                notify.historyCount = rows.length;
            }
        }
    }

    Component.onCompleted: refresh()
}
