pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// NetworkManager state via nmcli. Polled rather than pushed: nmcli has no
// cheap signal interface and the Command Center only needs a refresh while
// it is actually open (see `polling`).
//
// Ethernet, Wi-Fi and VPN profiles are all just connections here, so the UI
// needs no per-technology code — with one exception. A `tun` device is a
// tunnel some other application opened (a proprietary VPN client, say):
// NetworkManager can see it and can take it *down*, but has no profile to
// bring it back up. Those are reported as `external` and are deliberately
// read-only, because a toggle that only works in one direction is a trap.
QtObject {
    id: net

    // Set true by the Command Center while it is visible.
    property bool polling: false

    // [{ name, type, device, active, external }]
    property var connections: []

    readonly property var _activeReal: {
        var out = [];
        for (var i = 0; i < connections.length; i++) {
            var c = connections[i];
            if (c.active && c.type !== "loopback")
                out.push(c);
        }
        return out;
    }

    function _isVpn(t) {
        return t === "vpn" || t === "wireguard" || t === "tun";
    }

    readonly property var _primary: {
        for (var i = 0; i < _activeReal.length; i++)
            if (!_isVpn(_activeReal[i].type))
                return _activeReal[i];
        return null;
    }
    readonly property var _vpn: {
        for (var i = 0; i < _activeReal.length; i++)
            if (_isVpn(_activeReal[i].type))
                return _activeReal[i];
        return null;
    }

    readonly property bool connected: _primary !== null
    readonly property string primaryName: _primary ? _primary.name : ""
    readonly property string primaryType: _primary ? _primary.type : ""
    readonly property bool isWifi: primaryType.indexOf("wireless") !== -1 || primaryType === "wifi"

    readonly property bool vpnActive: _vpn !== null
    readonly property string vpnName: _vpn ? _vpn.name : ""

    // The VPN the tile's quick action may switch, or null. Externally
    // managed tunnels are excluded for the reason above, so on a machine
    // whose only tunnel is one of those this comes back null and the tile
    // simply offers no quick action — which is the honest answer, rather
    // than a button that half works.
    readonly property var togglableVpn: {
        for (var i = 0; i < connections.length; i++) {
            var c = connections[i];
            if (_isVpn(c.type) && !c.external)
                return c;
        }
        return null;
    }

    function toggleVpn() {
        toggle(togglableVpn);
    }

    // What the tile shows underneath "Network".
    readonly property string summary: {
        if (!connected)
            return vpnActive ? vpnName : "Offline";
        var base = isWifi ? primaryName : "Ethernet";
        return vpnActive ? base + " · VPN" : base;
    }

    // ── actions ─────────────────────────────────────────────────
    function up(name) {
        _run(["nmcli", "connection", "up", name]);
    }
    function down(name) {
        _run(["nmcli", "connection", "down", name]);
    }
    function toggle(conn) {
        if (!conn || conn.external)
            return;
        if (conn.active)
            down(conn.name);
        else
            up(conn.name);
    }

    // One nmcli action at a time. Restarting a Process that is still running
    // is how two connection changes end up racing, with the slower one
    // reporting last and the UI settling on the wrong state.
    property Process _action: Process {
        onExited: {
            net._actionBusy = false;
            net._settle.restart();
        }
    }
    property bool _actionBusy: false

    function _run(cmd) {
        if (_actionBusy)
            return;
        _actionBusy = true;
        _action.command = cmd;
        _action.running = true;
        // Give NetworkManager a beat to settle, then re-read.
        _settle.restart();
    }
    property Timer _settle: Timer {
        interval: 900
        onTriggered: net.refresh()
    }

    // ── polling ─────────────────────────────────────────────────
    function refresh() {
        if (!_probe.running)
            _probe.running = true;
    }

    property Timer _tick: Timer {
        interval: 5000
        repeat: true
        running: net.polling
        triggeredOnStart: true
        onTriggered: net.refresh()
    }

    // One nmcli call gives every connection plus which are up.
    property Process _probe: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,STATE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = ("" + text).split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (!line.length)
                        continue;
                    // nmcli -t escapes literal colons with a backslash;
                    // park those on a sentinel that cannot occur in the
                    // output, split on the real separators, then restore.
                    var parts = line.replace(/\\:/g, "\u0001").split(":");
                    for (var p = 0; p < parts.length; p++)
                        parts[p] = parts[p].replace(/\u0001/g, ":");
                    if (parts.length < 4)
                        continue;
                    var type = parts[1].replace("802-3-", "").replace("802-11-", "");
                    if (type === "loopback")
                        continue;
                    rows.push({
                        name: parts[0],
                        type: type,
                        device: parts[2],
                        active: parts[3] === "activated",
                        external: type === "tun"
                    });
                }
                net.connections = rows;
            }
        }
    }

    Component.onCompleted: refresh()
}
