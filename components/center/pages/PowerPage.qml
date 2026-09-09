import QtQuick
import "../../../"
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

// Session actions. Every one of these is irreversible, so nothing fires on
// a single tap: the first tap arms the row, the second commits, and the arm
// clears itself after a few seconds, on leaving the page, or the moment you
// tap something else.
//
// An armed row is tinted rather than accented. Accent everywhere else in the
// shell means "this is the one that is currently on"; here it would mean
// "the next click ends your session", and those two must not look alike.
Item {
    id: page
    implicitHeight: col.implicitHeight

    property string pending: ""

    function arm(action, run) {
        if (pending === action) {
            pending = "";
            disarm.stop();
            run();
            UiState.toHidden();
        } else {
            pending = action;
            disarm.restart();
        }
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: page.pending = ""
    }

    // Leaving the page forgets any armed action.
    Connections {
        target: CenterNav
        function onPageChanged() {
            page.pending = "";
            disarm.stop();
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 6

        PageHeader {
            width: parent.width
            title: "Power"
        }

        ListRow {
            width: parent.width
            glyph: Icons.logout
            label: "Log out"
            sublabel: page.pending === "logout" ? "Tap again to confirm" : "Ends the Hyprland session"
            selected: page.pending === "logout"
            tint: Theme.negative
            onActivated: page.arm("logout", Power.logout)
        }
        ListRow {
            width: parent.width
            glyph: Icons.suspend
            label: "Suspend"
            sublabel: page.pending === "suspend" ? "Tap again to confirm" : ""
            selected: page.pending === "suspend"
            tint: Theme.negative
            onActivated: page.arm("suspend", Power.suspend)
        }
        ListRow {
            width: parent.width
            glyph: Icons.restart
            label: "Restart"
            sublabel: page.pending === "reboot" ? "Tap again to confirm" : ""
            selected: page.pending === "reboot"
            tint: Theme.negative
            onActivated: page.arm("reboot", Power.reboot)
        }
        ListRow {
            width: parent.width
            glyph: Icons.power
            label: "Shut down"
            sublabel: page.pending === "shutdown" ? "Tap again to confirm" : ""
            selected: page.pending === "shutdown"
            tint: Theme.negative
            onActivated: page.arm("shutdown", Power.shutdown)
        }
    }
}
