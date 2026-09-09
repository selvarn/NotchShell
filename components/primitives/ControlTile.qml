import QtQuick
import "../.."
import "../../core"

// A Command Center tile with two levels of interaction:
//
//   • QUICK ACTION — tapping the icon badge flips the thing on or off right
//     there, without leaving the sheet. Only offered when `quick` is set,
//     which a tile does only if it actually has a meaningful binary state.
//   • DRILL-DOWN — tapping anywhere else on the card opens the detail page
//     (shown by the trailing chevron).
//
// A tile with `drill` but no `quick` opens on any tap; a tile with `quick`
// but no `drill` toggles on any tap. The badge is what carries state, so the
// card itself stays quiet.
SoftCard {
    id: tile

    property string glyph: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool drill: false
    property bool quick: false
    property bool enabled: true
    // Set while an action is in flight, so the tile can show that the system
    // hasn't caught up yet rather than lying about the new state.
    property bool busy: false

    signal toggled
    signal opened

    implicitHeight: Config.tileHeight
    radius: Config.rMd
    hovered: (ma.containsMouse || badgeMa.containsMouse) && enabled
    pressed: ma.pressed && enabled
    opacity: enabled ? 1 : 0.4

    Behavior on opacity {
        NumberAnimation { duration: Config.contentFadeDur }
    }

    // Card-level tap. Declared before the badge so the badge, being later in
    // the child order, gets first refusal on a press inside it.
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (tile.drill)
                tile.opened();
            else if (tile.quick)
                tile.toggled();
        }
    }

    // Icon badge — the state indicator, and the quick-action target.
    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: width / 2
        antialiasing: true
        z: 1

        color: tile.active ? Theme.accent : (tile.quick && badgeMa.containsMouse ? Theme.surfaceActive : Theme.sunken)
        scale: tile.quick && badgeMa.pressed ? 0.9 : 1.0
        // Quick actions are optimistic, so the badge says out loud when the
        // system hasn't confirmed yet instead of pretending it is done.
        opacity: tile.busy ? 0.55 : 1.0

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Config.easeFade }
        }
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Config.easeFade }
        }

        Icon {
            anchors.centerIn: parent
            text: tile.glyph
            size: 15
            color: tile.active ? Theme.accentText : Theme.textSecondary
        }

        MouseArea {
            id: badgeMa
            anchors.fill: parent
            // A 36 px circle is a small target; give it a few px of slop
            // without letting it reach the label.
            anchors.margins: -3
            hoverEnabled: true
            enabled: tile.enabled && tile.quick
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }
    }

    Item {
        anchors.left: badge.right
        anchors.leftMargin: 11
        anchors.right: chevron.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        height: texts.implicitHeight

        Column {
            id: texts
            width: parent.width
            spacing: 1

            Text {
                width: parent.width
                text: tile.label
                color: Theme.textPrimary
                font.family: Theme.fontSans
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                width: parent.width
                text: tile.sublabel
                visible: text.length > 0
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    Icon {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        visible: tile.drill
        // An invisible item still reserves its anchor width, which would
        // silently steal a chevron's worth of room from the label.
        box: tile.drill ? Math.round(10 * Config.iconBoxScale) : 0
        text: Icons.chevronRight
        size: 10
        color: Theme.textFaint
    }
}
