pragma Singleton

import QtQuick

// Semantic name → Nerd Font glyph. Every codepoint here is from the
// FontAwesome 4 range (U+F000–U+F2FF) that every Nerd Font patch includes,
// so nothing depends on an icon theme being installed.
//
// Use with `font.family: Theme.fontIcon`.
QtObject {
    readonly property string volumeHigh: ""
    readonly property string volumeLow: ""
    readonly property string volumeMute: ""
    readonly property string mic: ""
    readonly property string micMute: ""
    readonly property string headphones: ""

    readonly property string wifi: ""
    readonly property string ethernet: ""
    readonly property string vpn: ""
    readonly property string globe: ""

    readonly property string bell: ""
    readonly property string bellOff: ""

    readonly property string power: ""
    readonly property string restart: ""
    readonly property string suspend: ""
    readonly property string logout: ""

    readonly property string play: ""
    readonly property string pause: ""
    readonly property string prev: ""
    readonly property string next: ""
    readonly property string music: ""

    readonly property string chevronLeft: ""
    readonly property string chevronRight: ""
    readonly property string check: ""

    readonly property string search: ""
    readonly property string apps: ""
    readonly property string image: ""
    readonly property string terminal: ""

    readonly property string calendar: ""
    readonly property string sun: ""
    readonly property string moon: ""
}
