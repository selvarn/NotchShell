import QtQuick
import "../../"

// A single message, condensed to two lines. The shell does not own the
// notification bus (see services/Notify.qml), so nothing routes here on its
// own — this is the view behind `qs ipc call notch status notification …`,
// for a script that wants to say something in the notch.
Item {
    id: root

    property var payload: ({})
    readonly property string summary: (payload && payload.summary) ? payload.summary : ""
    readonly property string bodyText: (payload && payload.body) ? payload.body : ""

    implicitWidth: Math.min(260, Math.max(sum.implicitWidth, msg.implicitWidth))
    implicitHeight: col.implicitHeight

    Column {
        id: col
        anchors.centerIn: parent
        width: root.implicitWidth
        spacing: 2

        Text {
            id: sum
            width: parent.width
            text: root.summary
            color: Theme.textPrimary
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            id: msg
            width: parent.width
            text: root.bodyText
            visible: text.length > 0
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 10
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
