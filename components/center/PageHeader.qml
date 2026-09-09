import QtQuick
import "../../"
import "../../core"
import "../primitives"

// Back chevron + title for a drill-down page.
Item {
    id: header
    implicitHeight: Config.pageHeaderHeight

    property string title: ""

    IconButton {
        id: back
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 30
        implicitHeight: 30
        glyph: Icons.chevronLeft
        glyphSize: 12
        onClicked: CenterNav.back()
    }

    Text {
        anchors.left: back.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: header.title
        color: Theme.textPrimary
        font.family: Theme.fontSans
        font.pixelSize: 16
        font.weight: Font.Bold
    }
}
