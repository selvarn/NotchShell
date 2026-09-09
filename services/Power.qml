pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Session and power actions. Every one of these is irreversible from the
// UI's point of view, so the Power page always asks for a second tap before
// calling anything here — none of these fire on a single click.
QtObject {
    id: power

    function shutdown() {
        _run(["systemctl", "poweroff"]);
    }
    function reboot() {
        _run(["systemctl", "reboot"]);
    }
    function suspend() {
        _run(["systemctl", "suspend"]);
    }
    // The one action here the compositor owns rather than systemd. Hypr
    // knows which of Hyprland's two dispatch grammars this machine speaks;
    // this side only has to know that it wants the session to end.
    function logout() {
        Hypr.exit();
    }

    // These fire once and end the session; never restart the Process out
    // from under a command that is already on its way.
    property Process _action: Process {
        onExited: power._actionBusy = false
    }
    property bool _actionBusy: false

    function _run(cmd) {
        if (_actionBusy)
            return;
        _actionBusy = true;
        _action.command = cmd;
        _action.running = true;
    }
}
