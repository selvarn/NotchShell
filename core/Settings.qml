pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The user's config, and the only thing in the shell that reads it.
//
// `shell.conf` sits next to `shell.qml` and is deliberately small: a handful
// of choices, not a mirror of the internals. Everything the shell actually
// runs on — the tone ladder, the motion schedule, the shape of the notch —
// is derived from these few answers in Config.qml and Theme.qml, so a person
// editing the config never has to know that any of that exists.
//
// Three rules hold that line:
//   • every value is validated here and clamped to something the shell can
//     draw. A typo, a missing file, a nonsense number: the shell keeps its
//     default and stays usable. The config can never break the UI.
//   • nothing else in the shell parses text. Components read Config/Theme,
//     Config/Theme read this, this reads the file.
//   • what is not here is not configurable, on purpose.
//
// The file is watched, so saving it re-themes and re-tunes the running shell
// the same way editing a component does.
QtObject {
    id: settings

    // Next to shell.qml — so a copy of the shell run from anywhere else
    // (`qs -p ~/dev/shell.qml`) reads that copy's config, not this one.
    readonly property string path: {
        var dir = "" + Quickshell.shellDir;
        return (dir.startsWith("file://") ? dir.slice(7) : dir) + "/shell.conf";
    }

    property var _map: ({})

    property FileView _file: FileView {
        path: settings.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: settings._parse()
        // No file at all is a valid state: every default below stands on its
        // own, so the shell runs unconfigured.
        onLoadFailed: settings._map = ({})
    }

    Component.onCompleted: _parse()

    // ── the format ───────────────────────────────────────────────
    //
    //     section {
    //         key = value      # trailing comment
    //     }
    //
    // Hyprland's shape, minus everything that is not needed: no nesting, no
    // variables, no arithmetic. A `#` opens a comment when it begins a line
    // or stands on its own; `#7aa2f7` is a colour, not a truncated line.
    function _parse() {
        var out = {};
        var section = "";
        var lines = ("" + _file.text()).split("\n");

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].replace(/^\s*#.*$/, "").replace(/\s#(\s.*)?$/, "").trim();
            if (line.length === 0)
                continue;

            if (line === "}") {
                section = "";
                continue;
            }

            var open = line.indexOf("{");
            if (open >= 0 && line.indexOf("=") < 0) {
                section = line.slice(0, open).trim().toLowerCase();
                continue;
            }

            var eq = line.indexOf("=");
            if (eq < 0)
                continue;

            var key = line.slice(0, eq).trim().toLowerCase();
            if (key.length === 0)
                continue;
            out[(section ? section + "." : "") + key] = line.slice(eq + 1).trim();
        }
        _map = out;
    }

    // ── typed reads, all of them forgiving ───────────────────────
    function _str(key, def) {
        var v = _map[key];
        return (v === undefined || v.length === 0) ? def : v;
    }

    function _num(key, def, lo, hi) {
        var v = parseFloat(_map[key]);
        if (isNaN(v))
            return def;
        return v < lo ? lo : v > hi ? hi : v;
    }

    function _bool(key, def) {
        var v = _map[key];
        if (v === undefined)
            return def;
        v = v.toLowerCase();
        if (v === "true" || v === "yes" || v === "on" || v === "1")
            return true;
        if (v === "false" || v === "no" || v === "off" || v === "0")
            return false;
        return def;
    }

    // One of a fixed set, case-insensitively; anything else is the default.
    function _pick(key, allowed, def) {
        var v = _str(key, def).toLowerCase();
        return allowed.indexOf(v) >= 0 ? v : def;
    }

    // Comma-separated. Empty entries are dropped, so a trailing comma and an
    // empty list both mean "nothing".
    function _list(key, def) {
        var v = _map[key];
        if (v === undefined)
            return def;
        var parts = v.split(",");
        var out = [];
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i].trim();
            if (p.length > 0)
                out.push(p);
        }
        return out.length > 0 ? out : def;
    }

    // ── look ─────────────────────────────────────────────────────
    // "auto" follows the wallpaper's own brightness.
    readonly property string theme: _pick("look.theme", ["auto", "dark", "light"], "auto")
    // "auto" takes the most colourful swatch pywal found in the wallpaper.
    readonly property string accent: _str("look.accent", "auto")
    // How round everything is, as one decision. Scales the card radii, the
    // sheet's corners and — more gently, because the silhouette depends on
    // it — the notch's own.
    readonly property real rounding: {
        var named = {
            sharp: 0.35,
            soft: 1.0,
            round: 1.4
        };
        var raw = _str("look.rounding", "soft").toLowerCase();
        if (named[raw] !== undefined)
            return named[raw];
        return _num("look.rounding", 1.0, 0, 2);
    }
    readonly property string font: _str("look.font", "Inter")
    readonly property string monoFont: _str("look.mono_font", "JetBrains Mono")

    // ── notch ────────────────────────────────────────────────────
    readonly property real notchWidth: _num("notch.width", 172, 90, 520)
    readonly property real notchHeight: _num("notch.height", 34, 20, 80)
    // Seconds a status (volume, workspace, layout) owns the notch.
    readonly property int statusTime: Math.round(_num("notch.status_time", 1.7, 0.4, 10) * 1000)

    // ── panel (the Command Center) ───────────────────────────────
    readonly property real panelWidth: _num("panel.width", 500, 320, 900)
    // A multiplier on every animation the shell plays. Below 1 is quicker.
    readonly property real animationSpeed: _num("panel.animation_speed", 1.0, 0.25, 4)

    // ── launcher ─────────────────────────────────────────────────
    readonly property real launcherWidth: _num("launcher.width", 640, 380, 1100)
    readonly property int launcherRows: Math.round(_num("launcher.rows", 7, 3, 14))
    // Desktop id or visible name, case-insensitively; a trailing `*` hides a
    // whole family ("Avahi *").
    readonly property var hiddenApps: _list("launcher.hidden_apps", [])

    // ── system ───────────────────────────────────────────────────
    // Split on spaces: the .desktop entry's own argv is appended to it.
    readonly property var terminal: _str("system.terminal", "kitty -e").split(/\s+/)
    readonly property string wallpaperDir: _str("system.wallpapers", "Pictures/Wallpapers")
    readonly property var keyboardLayouts: _list("system.keyboard_layouts", ["en", "ru"])
    readonly property string hyprlandDispatch: _pick("system.hyprland_dispatch", ["auto", "native", "lua"], "auto")

    // The two commands that put a picture on the screen and re-colour the
    // shell from it. Left out of the config file itself — the defaults work
    // on this machine — but overridable for a different wallpaper daemon.
    readonly property string wallpaperCommand: _str("system.wallpaper_command", "awww img %f --resize crop --transition-type grow --transition-pos %x,%y --transition-duration 1.1 --transition-fps 60")
    readonly property string paletteCommand: _str("system.palette_command", "wal --backend schemer2 -n -i %f")
}
