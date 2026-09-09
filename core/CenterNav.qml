pragma Singleton

import QtQuick

// Which page the Command Center is showing. Drill-down is a transformation
// of the same sheet, not a new window — so this is just a string, and the
// sheet animates between root and detail.
QtObject {
    id: nav

    // "root" | "network" | "audio" | "nightlight" | "notifications" | "power" | "calendar"
    property string page: "root"
    readonly property bool atRoot: page === "root"

    function go(p) {
        nav.page = p;
    }

    // Two names for the same move, because they are raised by different
    // things and could reasonably diverge: `back` is the user pressing the
    // chevron, `reset` is the sheet tidying up after it has closed.
    function back() {
        nav.page = "root";
    }
    function reset() {
        nav.page = "root";
    }
}
