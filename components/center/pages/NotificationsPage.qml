import QtQuick
import "../../../"
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

// Do Not Disturb plus recent notification history, read from dunst. The
// shell drives dunst rather than claiming the notification bus itself, so
// nothing here interferes with normal notification delivery.
Item {
    id: page
    implicitHeight: col.implicitHeight

    readonly property int shown: Math.min(5, Notify.history.length)

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        PageHeader {
            width: parent.width
            title: "Notifications"
        }

        ControlTile {
            width: parent.width
            glyph: Notify.paused ? Icons.bellOff : Icons.bell
            label: "Do Not Disturb"
            sublabel: Notify.paused ? "Notifications are silenced" : "Notifications are delivered"
            active: Notify.paused
            onToggled: Notify.toggle()
        }

        Item {
            width: parent.width
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Recent"
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear"
                visible: Notify.history.length > 0
                color: clearMa.containsMouse ? Theme.accent : Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 11
                font.weight: Font.DemiBold

                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notify.clearHistory()
                }
            }
        }

        Text {
            width: parent.width
            text: "Nothing here yet"
            visible: Notify.history.length === 0
            color: Theme.textFaint
            font.family: Theme.fontSans
            font.pixelSize: 12
        }

        Column {
            width: parent.width
            spacing: 6

            Repeater {
                model: page.shown
                delegate: ListRow {
                    required property int index
                    readonly property var item: Notify.history[index]
                    width: col.width
                    label: item && item.summary ? item.summary : ""
                    sublabel: item && item.body ? item.body : ""
                    trailingText: item && item.app ? item.app : ""
                    enabled: false
                }
            }
        }

        Text {
            width: parent.width
            text: (Notify.history.length - page.shown) + " more in history"
            visible: Notify.history.length > page.shown
            color: Theme.textFaint
            font.family: Theme.fontSans
            font.pixelSize: 11
        }
    }
}
