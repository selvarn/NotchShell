import QtQuick
import "../.."

// Round icon button used by the media transport and page headers.
Rectangle {
    id: btn

    property string glyph: ""
    property real glyphSize: 14
    property bool filled: false
    property bool enabled: true
    signal clicked

    implicitWidth: 34
    implicitHeight: 34
    radius: width / 2
    antialiasing: true

    opacity: enabled ? 1 : 0.32

    color: !enabled ? "transparent" : filled ? Theme.accent : ma.pressed ? Theme.surfaceActive : ma.containsMouse ? Theme.surfaceHover : "transparent"

    scale: ma.pressed && enabled ? 0.9 : 1.0

    Behavior on color {
        ColorAnimation { duration: 120; easing.type: Config.easeFade }
    }
    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: Config.contentFadeDur }
    }

    Icon {
        anchors.centerIn: parent
        text: btn.glyph
        size: btn.glyphSize
        color: btn.filled ? Theme.accentText : Theme.textPrimary
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
