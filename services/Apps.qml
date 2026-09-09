pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// The installed applications, read straight from the `.desktop` files.
//
// ── why this does not use Quickshell's DesktopEntries ───────────────────
// It would be the obvious choice, and it returns nothing on a session where
// `XDG_DATA_DIRS` is unset — which a bare Hyprland session, started from a
// TTY rather than a display manager, very often is. The built-in scanner
// also came back empty when the variable was supplied by hand. So the search
// path is worked out here instead: the XDG variables when the session set
// them, and the specification's own defaults when it did not. Either way the
// files are read directly, which is what every other service in this shell
// does with the system it talks to.
//
// The scan is one shell command and one parse, both cheap, and it is redone
// on demand rather than watched: applications are installed a few times a
// month, and a launcher that is about to be *shown* is the natural moment to
// ask again.
QtObject {
    id: apps

    readonly property string _home: Quickshell.env("HOME") || ""

    // In precedence order — the first definition of a given desktop id wins,
    // so a user override in ~/.local shadows the system copy. Built from
    // XDG_DATA_HOME/XDG_DATA_DIRS where the session provides them, with the
    // spec's defaults standing in where it does not; the Flatpak exports are
    // appended because a Flatpak install adds them to XDG_DATA_DIRS only for
    // sessions started through a display manager.
    readonly property var searchPath: {
        var roots = [];
        function add(dir) {
            if (dir && dir.length && roots.indexOf(dir) < 0)
                roots.push(dir);
        }

        add(Quickshell.env("XDG_DATA_HOME") || (_home + "/.local/share"));

        var dirs = Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share";
        var parts = ("" + dirs).split(":");
        for (var i = 0; i < parts.length; i++)
            add(parts[i]);

        add(_home + "/.local/share/flatpak/exports/share");
        add("/var/lib/flatpak/exports/share");

        var out = [];
        for (var j = 0; j < roots.length; j++)
            out.push(roots[j] + "/applications");
        return out;
    }

    // Two-letter locale, used to prefer `Name[ru]` over `Name`.
    readonly property string locale: {
        var l = Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "";
        return l.length >= 2 ? l.substring(0, 2).toLowerCase() : "";
    }

    // Everything the scan found: [{ id, name, generic, comment, icon, exec,
    // terminal, command, _n, _g, _k, _c, _e }]
    property var _raw: []
    property bool ready: false

    // What the launcher may show. A binding rather than a filter applied at
    // scan time, so the hidden list is a view over the scan rather than
    // something baked into it — the scan stays a faithful reading of the
    // system, and only one place decides what is worth showing.
    readonly property var all: {
        var out = [];
        for (var i = 0; i < _raw.length; i++)
            if (!_isHidden(_raw[i]))
                out.push(_raw[i]);
        return out;
    }

    // Matches a desktop id or a visible name, case-insensitively; a trailing
    // `*` matches a prefix so one line can hide a family.
    function _isHidden(e) {
        var list = Config.hiddenApps;
        if (!list || !list.length)
            return false;
        for (var i = 0; i < list.length; i++) {
            var p = ("" + list[i]).trim().toLowerCase();
            if (!p.length)
                continue;
            if (p.charAt(p.length - 1) === "*") {
                var pre = p.substring(0, p.length - 1);
                if (e.id.toLowerCase().indexOf(pre) === 0 || e._n.indexOf(pre) === 0)
                    return true;
            } else if (e.id.toLowerCase() === p || e._n === p) {
                return true;
            }
        }
        return false;
    }

    function refresh() {
        if (_scan.running)
            return;
        _scan.running = true;
    }

    // Once at startup, so the first summon shows a list rather than a spinner;
    // the launcher re-runs it on every open to catch new installs.
    Component.onCompleted: apps.refresh()

    // ═══════════════════════════════════════════════════════════
    //  Scan
    // ═══════════════════════════════════════════════════════════

    // One process, one read. Records are framed with ASCII RS/US, which are
    // the two bytes a `.desktop` file is guaranteed never to contain — so the
    // whole listing comes back as a single string that cannot be ambiguous
    // however odd a file's contents are.
    readonly property string _script: {
        var dirs = "";
        for (var i = 0; i < searchPath.length; i++)
            dirs += " '" + searchPath[i] + "'";
        return "for d in" + dirs + "; do [ -d \"$d\" ] || continue; " + "for f in \"$d\"/*.desktop; do [ -f \"$f\" ] || continue; " + "printf '\\036%s\\037' \"$f\"; cat \"$f\"; done; done";
    }

    property Process _scan: Process {
        command: ["sh", "-c", apps._script]
        stdout: StdioCollector {
            onStreamFinished: apps._ingest("" + text)
        }
    }

    function _ingest(text) {
        var seen = ({});
        var out = [];
        var records = text.split("\u001e");

        for (var i = 0; i < records.length; i++) {
            var rec = records[i];
            if (!rec.length)
                continue;
            var cut = rec.indexOf("\u001f");
            if (cut < 0)
                continue;

            var path = rec.substring(0, cut);
            var id = path.substring(path.lastIndexOf("/") + 1).replace(/\.desktop$/, "");
            if (seen[id])
                continue;      // an earlier directory already defined this one

            var e = _parse(id, rec.substring(cut + 1));
            if (!e)
                continue;
            seen[id] = true;
            out.push(e);
        }

        apps._raw = out;
        apps.ready = true;
    }

    // Reads only the `[Desktop Entry]` group; every other group in the file
    // describes an action, which this launcher does not offer.
    function _parse(id, body) {
        var kv = ({});
        var lines = body.split("\n");
        var inGroup = false;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var t = line.trim();
            if (!t.length || t.charAt(0) === "#")
                continue;
            if (t.charAt(0) === "[") {
                inGroup = t === "[Desktop Entry]";
                continue;
            }
            if (!inGroup)
                continue;
            var eq = t.indexOf("=");
            if (eq < 1)
                continue;
            kv[t.substring(0, eq).trim()] = t.substring(eq + 1).trim();
        }

        if (kv["Type"] !== "Application")
            return null;
        if (kv["NoDisplay"] === "true" || kv["Hidden"] === "true")
            return null;

        var name = kv["Name[" + locale + "]"] || kv["Name"] || id;
        var exec = _cleanExec(kv["Exec"] || "");
        if (!exec.length)
            return null;

        var generic = kv["GenericName[" + locale + "]"] || kv["GenericName"] || "";
        var comment = kv["Comment[" + locale + "]"] || kv["Comment"] || "";
        var keywords = kv["Keywords[" + locale + "]"] || kv["Keywords"] || "";
        var terminal = kv["Terminal"] === "true";

        var argv = _tokenize(exec);
        if (terminal)
            argv = Config.terminalCommand.concat(argv);

        return {
            id: id,
            name: name,
            generic: generic,
            comment: comment,
            icon: kv["Icon"] || "",
            exec: exec,
            terminal: terminal,
            command: argv,
            // Lower-cased once, here, so scoring a keystroke is pure
            // comparison and never allocates.
            _n: name.toLowerCase(),
            _g: generic.toLowerCase(),
            _c: comment.toLowerCase(),
            _k: keywords.toLowerCase(),
            _e: exec.toLowerCase()
        };
    }

    // Field codes stand for files and URLs the launcher never passes, and the
    // spec says an unfilled code must be dropped rather than handed to the
    // program. `%%` is a literal percent and has to survive that removal, so
    // it is parked out of the way first.
    function _cleanExec(exec) {
        return exec.replace(/%%/g, "\u0000").replace(/%[fFuUdDnNickvm]/g, "").replace(/\u0000/g, "%").replace(/\s+/g, " ").trim();
    }

    // Exec is a shell-ish argv, not a shell command: quotes group, backslash
    // escapes inside them, and nothing else is special. Splitting it here
    // means the program is executed directly, with no shell to reinterpret a
    // name that happens to contain a metacharacter.
    function _tokenize(s) {
        var out = [];
        var cur = "";
        var quoted = false;
        for (var i = 0; i < s.length; i++) {
            var c = s.charAt(i);
            if (c === "\"") {
                quoted = !quoted;
                continue;
            }
            if (c === "\\" && quoted && i + 1 < s.length) {
                cur += s.charAt(++i);
                continue;
            }
            if (!quoted && (c === " " || c === "\t")) {
                if (cur.length) {
                    out.push(cur);
                    cur = "";
                }
                continue;
            }
            cur += c;
        }
        if (cur.length)
            out.push(cur);
        return out;
    }

    // ═══════════════════════════════════════════════════════════
    //  Search
    // ═══════════════════════════════════════════════════════════

    // Ranked, not filtered. Every field an entry has is searchable, but they
    // are not worth the same: a name that starts with what you typed beats a
    // name that merely contains it, which beats a match hidden in a comment.
    //
    // These are deliberately COARSE buckets with no tie-breaking of their own,
    // because the tie-break is the interesting part — see `search`, where how
    // often you actually launch a thing decides between two equally good
    // textual matches.
    function _score(a, q) {
        if (a._n === q)
            return 100;
        if (a._n.indexOf(q) === 0)
            return 90;
        if ((" " + a._n).indexOf(" " + q) > 0)
            return 80;   // starts a word inside the name
        if (a._n.indexOf(q) > 0)
            return 70;
        if (a._g.indexOf(q) >= 0)
            return 40;
        if (a._k.indexOf(q) >= 0)
            return 30;
        if (a._e.indexOf(q) === 0)
            return 25;   // typed the binary name
        if (a._c.indexOf(q) >= 0)
            return 15;
        if (a._e.indexOf(q) > 0)
            return 10;
        return 0;
    }

    // Relevance first, then how often you use it, the way wofi's drun mode
    // behaves. With no query typed there is no relevance to speak of, so the
    // list *is* the usage ranking — the things you actually open, in the order
    // you actually open them, which is the only useful order for a list of
    // forty-odd applications you never asked to see alphabetically.
    function search(query) {
        var q = ("" + query).trim().toLowerCase();
        var hasQuery = q.length > 0;
        var list = all;

        var scored = [];
        for (var i = 0; i < list.length; i++) {
            var s = hasQuery ? _score(list[i], q) : 1;
            if (s > 0)
                scored.push({
                    e: list[i],
                    s: s,
                    u: uses(list[i].id),
                    t: lastUsed(list[i].id)
                });
        }

        scored.sort(function (x, y) {
            if (x.s !== y.s)
                return y.s - x.s;
            if (x.u !== y.u)
                return y.u - x.u;
            // Same count: whichever was wanted more recently.
            if (x.t !== y.t)
                return y.t - x.t;
            // Only inside a query is a shorter name the better match —
            // "Files" over "Files (Recent Documents)" for the same prefix.
            if (hasQuery && x.e._n.length !== y.e._n.length)
                return x.e._n.length - y.e._n.length;
            return x.e._n < y.e._n ? -1 : 1;
        });

        var out = [];
        for (var j = 0; j < scored.length; j++)
            out.push(scored[j].e);
        return out;
    }

    // ═══════════════════════════════════════════════════════════
    //  Usage
    // ═══════════════════════════════════════════════════════════

    // { <desktop id>: { n: <launch count>, t: <last launch, ms> } }
    //
    // Kept next to the other caches rather than in the config: it is
    // observed behaviour, not a setting, and deleting the file should cost
    // nothing but a few days of the launcher re-learning.
    property var usage: ({})
    readonly property string usagePath: (Quickshell.env("XDG_CACHE_HOME") || (_home + "/.cache")) + "/notchshell-launcher.json"

    function uses(id) {
        var u = usage[id];
        return u ? u.n : 0;
    }
    function lastUsed(id) {
        var u = usage[id];
        return u ? u.t : 0;
    }

    function _record(id) {
        var u = usage[id];
        // Reassigned wholesale, not mutated: a `var` property only notifies
        // on assignment, and the results binding has to see the change.
        var next = ({});
        for (var k in usage)
            next[k] = usage[k];
        next[id] = {
            n: (u ? u.n : 0) + 1,
            t: Date.now()
        };
        usage = next;
        _saveDebounce.restart();
    }

    property FileView _usageFile: FileView {
        path: apps.usagePath
        // Nothing else writes this file, so watching it would only mean
        // reacting to our own saves.
        watchChanges: false
        atomicWrites: true
        onLoaded: {
            try {
                var v = JSON.parse("" + text());
                if (v && typeof v === "object")
                    apps.usage = v;
            } catch (e) {
                apps.usage = ({});
            }
        }
        // No file yet is the normal state on a fresh install. Writing an
        // empty one immediately means the read only ever fails once, instead
        // of logging on every launch until something is used.
        onLoadFailed: {
            apps.usage = ({});
            apps._usageFile.setText("{}");
        }
    }

    property Timer _saveDebounce: Timer {
        interval: 400
        onTriggered: apps._usageFile.setText(JSON.stringify(apps.usage))
    }

    // ═══════════════════════════════════════════════════════════
    //  Launch
    // ═══════════════════════════════════════════════════════════

    // Detached on purpose. A Quickshell `Process` is a child of the shell and
    // dies with it — which is exactly right for hyprsunset and exactly wrong
    // for the user's editor.
    function launch(entry) {
        if (!entry || !entry.command || entry.command.length === 0)
            return;
        _record(entry.id);
        Quickshell.execDetached(entry.command);
    }
}
