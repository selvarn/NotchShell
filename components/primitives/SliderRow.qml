import QtQuick
import "../../core"

// Horizontal slider with a leading icon that doubles as a toggle. The whole
// track is the drag surface (iOS-style), and the fill uses the accent so the
// value reads at a glance.
//
// `value` is the *displayed* value and stays under the caller's control, so a
// service can hold it optimistically while a slow backend catches up. Drags
// emit `moved` continuously — throttling belongs in the service that owns the
// hardware, not here, because only it knows how expensive a write is.
Item {
    id: row

    property string glyph: ""
    property string glyphOff: ""
    property real value: 0            // 0..1
    property bool off: false          // muted / disabled state
    property bool iconToggles: true
    // What the trailing readout shows. Defaults to a percentage.
    property string valueText: Math.round(Config.clamp(value, 0, 1) * 100) + "%"

    signal moved(real v)
    signal iconClicked

    implicitHeight: Config.sliderHeight

    // The icon's fixed lane, shared by the badge, the hit area and the drag
    // origin so all three agree on where the track actually starts.
    readonly property real iconLane: 40

    SoftCard {
        id: track
        anchors.fill: parent
        radius: height / 2
        sunken: true

        // Accent fill, clipped to the track's rounded shape.
        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                height: parent.height
                width: Math.max(parent.height, parent.width * Config.clamp(row.value, 0, 1))
                radius: parent.height / 2
                antialiasing: true
                color: row.off ? Theme.surfaceActive : Theme.accent
                opacity: row.off ? 0.5 : 0.9

                Behavior on width {
                    NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 160 }
                }
            }
        }

        Icon {
            id: icon
            anchors.left: parent.left
            // Centred in the icon lane rather than offset by a hand-picked
            // margin, so it lines up with every other icon in the sheet.
            anchors.leftMargin: (row.iconLane - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            text: row.off ? row.glyphOff : row.glyph
            size: 14
            // Ink sits on the accent fill near the left, so pick against it.
            color: row.off ? Theme.textMuted : Theme.accentText
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: row.valueText
            color: row.value > 0.86 ? Theme.accentText : Theme.textSecondary
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.weight: Font.DemiBold
            opacity: row.off ? 0.5 : 1
        }
    }

    // Icon hit area — toggles without moving the value.
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: row.iconLane
        enabled: row.iconToggles
        cursorShape: Qt.PointingHandCursor
        onClicked: row.iconClicked()
    }

    // Track hit area — click or drag anywhere to set the value.
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.leftMargin: row.iconToggles ? row.iconLane : 0
        cursorShape: Qt.PointingHandCursor

        function apply(mx) {
            var usable = row.width - (row.iconToggles ? row.iconLane : 0);
            if (usable <= 0)
                return;
            row.moved(Config.clamp(mx / usable, 0, 1));
        }
        onPressed: mouse => apply(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                apply(mouse.x);
        }
    }
}
