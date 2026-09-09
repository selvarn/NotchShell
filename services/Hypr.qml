pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"

// Thin, opinionated wrapper over Quickshell's native Hyprland integration.
//
// ── why dispatching is not one line ─────────────────────────────────────
// Hyprland has two incompatible dispatch grammars in the wild. Vanilla takes
// plain dispatchers — `workspace 3`. A Lua-configured Hyprland (the hyprglass
// plugin, and anything else that swaps hyprland.conf for hyprland.lua) hands
// the same string to a Lua interpreter and wants an expression instead —
// `hl.dsp.focus({ workspace = 3 })`. Sending the wrong one is not an
// exception: the compositor answers with a parse error nobody sees and the
// window simply does not move.
//
// So callers never write either grammar. They ask for an *intent* — focus a
// workspace, end the session — and `_phrase` renders it for whichever
// grammar this compositor actually speaks. The answer comes from a probe at
// startup (see `_grammarProbe`), and intents raised before it lands are held
// rather than guessed at, so the first click of a session behaves like every
// one after it.
QtObject {
    id: hypr

    // ── workspaces ───────────────────────────────────────────────
    readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var workspaces: Hyprland.workspaces ? Hyprland.workspaces.values : []

    readonly property int maxWorkspace: {
        var m = 1;
        for (var i = 0; i < workspaces.length; i++)
            if (workspaces[i].id > m)
                m = workspaces[i].id;
        return m;
    }

    function focusWorkspace(id) {
        if (id < 1)
            return;
        _dispatch("workspace", id);
    }

    // Name of the monitor that currently has focus, matched against
    // Quickshell's own screen list by the launcher so it opens where the
    // user is looking. Empty until Hyprland's collections populate.
    readonly property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    // ── keyboard layout ──────────────────────────────────────────
    // The short lowercase code the notch shows, e.g. "en" / "ru". Only the
    // code is kept: xkb's own name for a layout ("English (US)") is far too
    // long for a lip of a notch, and the shell has nowhere else to put it.
    property string layoutCode: "en"

    // Every layout the user actually has configured, in xkb order. Drives
    // the segmented switch, so it must stay in sync with kb_layout — which
    // is why it is a config value and not a guess made from the event feed.
    readonly property var layoutCodes: Config.layoutCodes
    readonly property int layoutIndex: Math.max(0, layoutCodes.indexOf(layoutCode))

    // xkb's descriptive name → our two-letter code. Matched loosely on
    // purpose: the same layout is announced differently by different
    // versions ("Russian", "ru", "Russian (phonetic)"), and anything
    // unrecognised falling back to "en" is better than a blank notch.
    function _applyLayout(name) {
        if (!name)
            return;
        var n = ("" + name).toLowerCase();
        if (n.indexOf("rus") !== -1 || n.startsWith("ru"))
            hypr.layoutCode = "ru";
        else if (n.indexOf("ukrain") !== -1)
            hypr.layoutCode = "ua";
        else if (n.indexOf("german") !== -1 || n.startsWith("de"))
            hypr.layoutCode = "de";
        else if (n.indexOf("french") !== -1)
            hypr.layoutCode = "fr";
        else
            hypr.layoutCode = "en";
    }

    // Cycle layouts the same way `grp:alt_shift_toggle` does. Deliberately a
    // plain process rather than a dispatch: `switchxkblayout` is a hyprctl
    // *command*, not a dispatcher, so it reads the same in both grammars and
    // needs none of the machinery below.
    function cycleLayout() {
        _switchLayout.running = true;
    }

    property Process _switchLayout: Process {
        command: ["hyprctl", "switchxkblayout", "current", "next"]
    }

    // ── dispatch ─────────────────────────────────────────────────

    // End the session. Named for what it does, not for how it is spelled.
    function exit() {
        _dispatch("exit");
    }

    // "native" | "lua", or "" while the probe is still out.
    property string grammar: Config.hyprlandDispatch === "auto" ? "" : Config.hyprlandDispatch
    readonly property bool grammarKnown: grammar.length > 0

    // Intent → the string this compositor understands. The single place that
    // knows either grammar; adding a dispatcher means adding one case here
    // and nothing anywhere else.
    function _phrase(kind, arg) {
        if (grammar === "lua") {
            switch (kind) {
            case "workspace":
                return "hl.dsp.focus({ workspace = " + arg + " })";
            case "exit":
                return "hl.dsp.exit()";
            }
            return "";
        }
        switch (kind) {
        case "workspace":
            return "workspace " + arg;
        case "exit":
            return "exit";
        }
        return "";
    }

    // Raised before the probe answered: hold it. One deep, because these are
    // all "go here now" intents — a queue of stale destinations would land
    // the user somewhere they asked for half a second ago and have already
    // changed their mind about.
    property var _held: null

    function _dispatch(kind, arg) {
        if (!grammarKnown) {
            _held = {
                kind: kind,
                arg: arg
            };
            return;
        }
        var expr = _phrase(kind, arg);
        if (!expr.length)
            return;
        try {
            Hyprland.dispatch(expr);
        } catch (e) {
            if (Config.debug)
                console.warn("Hypr dispatch failed:", expr, e);
        }
    }

    onGrammarChanged: {
        if (!grammarKnown || !_held)
            return;
        var h = _held;
        _held = null;
        _dispatch(h.kind, h.arg);
    }

    // Ask the compositor to dispatch something that cannot exist. Vanilla
    // Hyprland answers "Invalid dispatcher"; a Lua-configured one answers
    // with its own parse error, which names `hl.dispatch` — so the reply
    // identifies the grammar without either form having to be tried for
    // real, and without anything being dispatched if the guess is wrong.
    property Process _grammarProbe: Process {
        running: Config.hyprlandDispatch === "auto"
        command: ["sh", "-c", "hyprctl dispatch __notchshell_probe__ 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: hypr.grammar = ("" + text).indexOf("hl.dispatch") >= 0 ? "lua" : "native"
        }
    }

    // If the probe never answers — no hyprctl on PATH, or a compositor that
    // says nothing at all — settle on the grammar Hyprland ships with rather
    // than holding every later dispatch forever.
    property Timer _grammarFallback: Timer {
        interval: 2000
        running: Config.hyprlandDispatch === "auto"
        onTriggered: if (!hypr.grammarKnown)
            hypr.grammar = "native"
    }

    // ── event stream ─────────────────────────────────────────────
    // rawEvent fires for everything; we surface just what the shell needs
    // as clean signals so callers never parse Hyprland's wire format.
    signal workspaceChanged(int id)
    signal layoutChanged(string name)
    signal urgent

    property Connections _conn: Connections {
        target: Hyprland

        function onRawEvent(event) {
            var name = event.name;
            if (name === "workspace" || name === "workspacev2") {
                var wid = parseInt(("" + event.data).split(",")[0]);
                if (!isNaN(wid))
                    hypr.workspaceChanged(wid);
            } else if (name === "activelayout") {
                var parts = ("" + event.data).split(",");
                var lname = parts.length > 1 ? parts.slice(1).join(",") : event.data;
                hypr._applyLayout(lname);
                hypr.layoutChanged(lname);
            } else if (name === "urgent") {
                hypr.urgent();
            }
        }
    }

    // Pull the initial layout once devices are known, so the notch shows a
    // correct code before the first alt-shift toggle.
    property Process _initLayout: Process {
        running: true
        command: ["sh", "-c", "hyprctl devices -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    var kbs = d.keyboards || [];
                    for (var i = 0; i < kbs.length; i++) {
                        if (kbs[i].main && kbs[i].active_keymap) {
                            hypr._applyLayout(kbs[i].active_keymap);
                            return;
                        }
                    }
                    if (kbs.length && kbs[0].active_keymap)
                        hypr._applyLayout(kbs[0].active_keymap);
                } catch (e) {}
            }
        }
    }
}
