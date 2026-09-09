import QtQuick
import "../../"
import "../../core"
import "../primitives"

// Square time widget, iPhone-home-screen flavoured: weekday on top, big
// time, date underneath. Tapping it drills into the calendar.
SoftCard {
    id: tile

    implicitWidth: Config.clockTileSize
    implicitHeight: Config.clockTileSize
    radius: Config.rLg
    hovered: ma.containsMouse
    pressed: ma.pressed

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 2

        Text {
            text: Clock.weekday
            color: Theme.accent
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: parent.width
        }
        Text {
            text: Clock.time
            color: Theme.textPrimary
            font.family: Theme.fontSans
            font.pixelSize: 34
            font.weight: Font.Bold
            font.letterSpacing: -1
        }
        Text {
            text: Clock.date
            color: Theme.textSecondary
            font.family: Theme.fontSans
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width
        }
    }

    Icon {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        text: Icons.calendar
        size: 12
        color: Theme.textFaint
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: CenterNav.go("calendar")
    }
}
