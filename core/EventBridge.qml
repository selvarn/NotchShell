import QtQuick
import "../services"
import "."

// Turns system events into transient notch statuses. Instantiated once by
// shell.qml. Keeps that wiring out of both the services (which shouldn't
// know about the UI) and the views (which shouldn't poll).
QtObject {
    id: bridge

    // Suppress the startup burst of "current state" events.
    property bool _ready: false
    property Timer _readyTimer: Timer {
        interval: 1500
        running: true
        onTriggered: bridge._ready = true
    }

    property Connections _hypr: Connections {
        target: Hypr

        function onWorkspaceChanged(id) {
            if (!bridge._ready)
                return;
            UiState.notify("workspace", {
                id: id
            }, {
                priority: 1
            });
        }

        function onLayoutChanged() {
            if (!bridge._ready)
                return;
            UiState.notify("layout", {
                code: Hypr.layoutCode
            }, {
                priority: 2
            });
        }

        function onUrgent() {
            UiState.notify("workspace", {
                id: Hypr.focusedWorkspace
            }, {
                priority: 3
            });
        }
    }

    property Connections _audio: Connections {
        target: Audio

        // Surface every volume change (media keys included), not just
        // in-UI ones — this doubles as the system volume OSD.
        function onChanged() {
            if (!bridge._ready)
                return;
            UiState.notify("volume", {
                percent: Audio.volumePercent,
                muted: Audio.muted
            }, {
                priority: 2,
                ttl: 1200
            });
        }
    }
}
