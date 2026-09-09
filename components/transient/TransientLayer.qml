import QtQuick
import "../../"
import "../../core"

// Routes UiState.current → the matching status view. All four views stay
// mounted (they are cheap) and cross-fade on `kind`, so rapid status
// replacement never churns the scene. `desiredWidth` lets the notch size
// itself to whatever is showing.
Item {
    id: layer

    readonly property var cur: UiState.current
    readonly property string kind: cur ? cur.kind : ""
    readonly property var payload: cur ? cur.data : ({})

    readonly property real desiredWidth: {
        var it = kind === "workspace" ? ws : kind === "layout" ? lay : kind === "volume" ? vol : kind === "notification" ? notif : null;
        return it ? it.implicitWidth + 44 : Config.peekWidth;
    }

    component Slot: Item {
        anchors.fill: parent
        property bool on: false
        visible: opacity > 0.01
        opacity: on ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
        }
    }

    Slot {
        on: layer.kind === "workspace"
        WorkspaceTransient { id: ws; anchors.centerIn: parent; payload: layer.kind === "workspace" ? layer.payload : ({}) }
    }
    Slot {
        on: layer.kind === "layout"
        LayoutTransient { id: lay; anchors.centerIn: parent; payload: layer.kind === "layout" ? layer.payload : ({}) }
    }
    Slot {
        on: layer.kind === "volume"
        VolumeTransient { id: vol; anchors.centerIn: parent; payload: layer.kind === "volume" ? layer.payload : ({}) }
    }
    Slot {
        on: layer.kind === "notification"
        NotificationTransient { id: notif; anchors.centerIn: parent; payload: layer.kind === "notification" ? layer.payload : ({}) }
    }
}
