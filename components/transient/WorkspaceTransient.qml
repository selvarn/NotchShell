import QtQuick
import "../../services"
import "../../core"

// Compact workspace strip: a dot per workspace, the active one stretched into
// a numbered capsule. The stretch animates so a switch reads as motion.
Item {
    id: root

    // NB: never call this `data` — that name is QtObject's default (children)
    // property and shadowing it drops every child item.
    property var payload: ({})
    readonly property int activeId: (payload && payload.id) ? payload.id : Hypr.focusedWorkspace
    readonly property int count: Math.max(5, Hypr.maxWorkspace)

    implicitWidth: row.implicitWidth
    implicitHeight: 16

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.count
            delegate: Item {
                id: cell
                required property int index
                readonly property bool on: (index + 1) === root.activeId

                width: on ? 26 : 6
                height: 16

                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: cell.on ? 16 : 6
                    radius: height / 2
                    color: cell.on ? Theme.accent : Theme.textMuted

                    Behavior on height {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 160 }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: cell.on
                        text: cell.index + 1
                        color: Theme.accentText
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
