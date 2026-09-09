import QtQuick
import "../.."
import "../../core"

// A row inside a drill-down page: small leading glyph, label + sublabel, and
// a trailing check when it is the selected/active one.
SoftCard {
    id: row

    property string glyph: ""
    property string label: ""
    property string sublabel: ""
    property bool selected: false
    property bool enabled: true
    property string trailingText: ""
    // What "selected" is drawn in. Accent means "this is the active one",
    // which is what almost every row means; the Power page overrides it so an
    // armed, irreversible action does not look like an ordinary selection.
    property color tint: Theme.accent

    signal activated

    implicitHeight: 50
    radius: Config.rSm
    hovered: ma.containsMouse && enabled
    pressed: ma.pressed && enabled
    opacity: enabled ? 1 : 0.45

    Icon {
        id: lead
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        // Collapse the box rather than hiding it: an invisible Icon still
        // reserves its width for whatever anchors to its right edge.
        box: row.glyph.length ? Math.round(14 * Config.iconBoxScale) : 0
        visible: row.glyph.length > 0
        text: row.glyph
        size: 14
        color: row.selected ? row.tint : Theme.textMuted
    }

    Column {
        anchors.left: lead.right
        anchors.leftMargin: row.glyph.length ? 7 : 3
        anchors.right: trailing.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.label
            color: Theme.textPrimary
            font.family: Theme.fontSans
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            width: parent.width
            text: row.sublabel
            visible: text.length > 0
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    Item {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(check.visible ? 14 : 0, label.visible ? label.implicitWidth : 0)
        height: 16

        Icon {
            id: check
            anchors.centerIn: parent
            text: Icons.check
            size: 12
            color: row.tint
            visible: row.selected && row.trailingText.length === 0
        }
        Text {
            id: label
            anchors.centerIn: parent
            text: row.trailingText
            visible: row.trailingText.length > 0
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
