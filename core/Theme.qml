pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Colour system. Reads the live pywal palette (~/.cache/wal/colors.json),
// derives a small set of semantic tokens and adapts to a light or dark
// wallpaper.
//
// Two distinct materials, deliberately:
//   • the NOTCH is pure black and fully opaque — it must read as part of
//     the display bezel, never as a floating card. No border, no glass.
//   • the COMMAND CENTER is soft UI — a quiet dark panel with slightly
//     lifted, borderless cards. Depth comes from tone steps and roundness,
//     not from translucency or blur.
//
// Every component pulls colour from here. No literal hex in components, and
// no hex in the config either beyond the one accent a person may want to
// pin: light/dark, accent and the two font families are the whole of what
// `shell.conf` says about colour — the ladder is derived, so a palette can
// never come out half-legible.
QtObject {
    id: theme

    // ── palette source ───────────────────────────────────────────
    property string _home: Quickshell.env("HOME") || ""

    property FileView _wal: FileView {
        path: theme._home + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme._parse()
        onLoadFailed: theme._raw = null
    }

    property var _raw: null
    Component.onCompleted: _parse()

    function _parse() {
        try {
            theme._raw = JSON.parse(theme._wal.text());
        } catch (e) {
            theme._raw = null;
        }
    }

    // ── low-level helpers ────────────────────────────────────────
    function _col(key, fallback) {
        if (_raw && _raw.colors && _raw.colors[key])
            return _raw.colors[key];
        return fallback;
    }
    function _sp(key, fallback) {
        if (_raw && _raw.special && _raw.special[key])
            return _raw.special[key];
        return fallback;
    }
    function _lum(c) {
        var q = Qt.color(c);
        return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b;
    }
    function _chroma(c) {
        var q = Qt.color(c);
        return Math.max(q.r, q.g, q.b) - Math.min(q.r, q.g, q.b);
    }
    function _alpha(c, a) {
        var q = Qt.color(c);
        return Qt.rgba(q.r, q.g, q.b, a);
    }
    // A chosen family in front of the fallbacks, without repeating itself if
    // the choice is already one of them.
    function _stack(pick, fallbacks) {
        var list = fallbacks.split(", ").filter(function (f) {
            return f.toLowerCase() !== pick.toLowerCase();
        });
        list.unshift(pick);
        return list.join(", ");
    }

    // Linear blend between two colours. Used both to build the tone ladder
    // below and, by the notch, to morph its fill from bezel-black into the
    // Command Center's panel tone as the sheet opens.
    function blend(a, b, t) {
        var x = Qt.color(a), y = Qt.color(b);
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, x.a + (y.a - x.a) * t);
    }

    // ── raw wallpaper anchors ────────────────────────────────────
    readonly property color _wpBg: _sp("background", _col("color0", "#17141a"))
    readonly property color _wpFg: _sp("foreground", _col("color7", "#e8e6ea"))

    // `look.theme`: "auto" reads the wallpaper's own brightness.
    readonly property bool isLight: Settings.theme === "light" ? true : Settings.theme === "dark" ? false : _lum(_wpBg) > 0.62

    // Accent: whatever `look.accent` pins, else the most chromatic swatch
    // pywal produced. If the palette is near-greyscale we fall back to a calm
    // periwinkle so accents still read.
    readonly property color _pickedAccent: {
        if (_accentPinned)
            return Settings.accent;
        var keys = ["color5", "color4", "color6", "color2", "color3", "color1", "color13", "color12"];
        var best = null, bestC = 0;
        for (var i = 0; i < keys.length; i++) {
            var c = _col(keys[i], null);
            if (!c)
                continue;
            var ch = _chroma(c);
            if (ch > bestC) {
                bestC = ch;
                best = c;
            }
        }
        if (!best || bestC < 0.06)
            return "#8fa6e6";
        return best;
    }

    // ── the notch: bezel-black, opaque, borderless ───────────────
    readonly property color notchFill: "#000000"

    // ── the Command Center: soft UI tone ladder ──────────────────
    // panel  = the sheet itself
    // surface = a card resting on it
    // raised  = a card that needs a touch more presence (media)
    // sunken  = slider tracks, inset wells
    readonly property color panel: isLight ? blend(_wpBg, "#ffffff", 0.72) : blend(_wpBg, "#000000", 0.68)
    readonly property color surface: isLight ? blend(panel, "#000000", 0.05) : blend(panel, "#ffffff", 0.07)
    readonly property color surfaceHover: isLight ? blend(panel, "#000000", 0.09) : blend(panel, "#ffffff", 0.11)
    readonly property color surfaceActive: isLight ? blend(panel, "#000000", 0.14) : blend(panel, "#ffffff", 0.16)
    readonly property color raised: isLight ? "#ffffff" : blend(panel, "#ffffff", 0.10)
    readonly property color sunken: isLight ? blend(panel, "#000000", 0.10) : blend(panel, "#000000", 0.45)

    // Soft UI barely uses borders. These stay near-invisible and are only
    // applied where a surface would otherwise dissolve into the wallpaper.
    readonly property color border: _alpha(isLight ? "#000000" : "#ffffff", isLight ? 0.08 : 0.06)
    readonly property color separator: _alpha(isLight ? "#000000" : "#ffffff", 0.07)

    // ── text ─────────────────────────────────────────────────────
    readonly property color textPrimary: isLight ? "#1b1b20" : "#f3f2f5"
    readonly property color textSecondary: _alpha(textPrimary, 0.66)
    readonly property color textMuted: _alpha(textPrimary, 0.40)
    readonly property color textFaint: _alpha(textPrimary, 0.22)

    // ── accent ───────────────────────────────────────────────────
    // A pinned accent is taken exactly as written — someone who typed a hex
    // code has already decided. Only a colour *derived* from the wallpaper
    // gets pushed toward legibility, because nobody chose it.
    readonly property bool _accentPinned: /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(Settings.accent)

    readonly property color accent: {
        if (_accentPinned)
            return _pickedAccent;
        var q = Qt.color(_pickedAccent);
        var s = Math.min(1.0, q.hslSaturation * 1.35 + 0.05);
        var l = isLight ? Math.min(0.6, q.hslLightness) : Math.max(0.62, Math.min(0.78, q.hslLightness + 0.08));
        return Qt.hsla(q.hslHue, s, l, 1.0);
    }
    readonly property color accentText: _lum(accent) > 0.55 ? "#141317" : "#f7f7fa"

    readonly property color scrim: _alpha("#000000", isLight ? 0.14 : 0.34)

    // For the one thing in the shell that is worth a colour of its own: an
    // armed, irreversible action on the Power page. Muted rather than alarm
    // red — it is a warning, not an error that has already happened.
    readonly property color negative: blend("#e06c75", textPrimary, 0.1)

    // ── typography ───────────────────────────────────────────────
    // `look.font` / `look.mono_font`, each with a fallback chain behind it so
    // a font that is not installed degrades instead of disappearing.
    readonly property string fontSans: _stack(Settings.font, "Inter, Roboto, -apple-system, Sans-Serif")
    readonly property string fontMono: _stack(Settings.monoFont, "JetBrains Mono, monospace")
    // Nerd Font is installed system-wide; it supplies every icon glyph so
    // the shell needs no icon theme and no SVG assets.
    readonly property string fontIcon: "JetBrainsMono Nerd Font"
}
