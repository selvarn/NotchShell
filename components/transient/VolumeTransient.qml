import QtQuick
import "../../services"
import "../../core"

// Volume: a segmented meter + percent. No icon font — the segments carry the
// meaning; the muted state dims everything and swaps the label.
Item {
    id: root

    property var payload: ({})
    readonly property int percent: (payload && payload.percent !== undefined) ? payload.percent : Audio.volumePercent
    readonly property bool muted: (payload && payload.muted !== undefined) ? payload.muted : Audio.muted

    readonly property int segs: 12
    implicitWidth: line.implicitWidth
    implicitHeight: 16

    Row {
        id: line
        anchors.centerIn: parent
        spacing: 12

        Row {
            spacing: 3
            Repeater {
                model: root.segs
                delegate: Rectangle {
                    required property int index
                    readonly property bool lit: !root.muted && (index / root.segs) < (root.percent / 100)
                    width: 5
                    height: 14
                    radius: 2
                    color: lit ? Theme.accent : Theme.sunken
                    border.width: lit ? 0 : 1
                    border.color: Theme.border
                    Behavior on color {
                        ColorAnimation { duration: 110 }
                    }
                }
            }
        }

        Text {
            height: 14
            verticalAlignment: Text.AlignVCenter
            text: root.muted ? "muted" : root.percent + "%"
            color: root.muted ? Theme.textMuted : Theme.textSecondary
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
