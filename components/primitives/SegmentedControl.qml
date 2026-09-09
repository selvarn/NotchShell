import QtQuick
import "../.."

// Two-or-more segment switch with an indicator that physically travels
// between positions: a spring carries it, and it stretches along the
// direction of motion while in flight, then settles back. Used for the
// keyboard layout status.
Item {
    id: seg

    property var items: ["en", "ru"]
    property int currentIndex: 0
    property real segWidth: 36
    property real segHeight: 24
    property real spacing: 2
    property real pad: 3
    property int fontSize: 12
    property bool interactive: true

    signal segmentClicked(int index)

    implicitWidth: items.length * segWidth + (items.length - 1) * spacing + pad * 2
    implicitHeight: segHeight + pad * 2

    function _slotX(i) {
        return pad + i * (segWidth + spacing);
    }

    // Where the indicator is heading, and where it actually is.
    readonly property real _target: _slotX(Config.clamp(currentIndex, 0, items.length - 1))
    // A plain binding, not a change handler: handlers can run before the
    // dependent `_target` has re-evaluated, which would leave the indicator
    // chasing the previous slot.
    property real _pos: _target

    Behavior on _pos {
        SpringAnimation {
            spring: Config.springStiffness
            damping: Config.springDamping
            mass: Config.springMass
            epsilon: 0.2
        }
    }

    // Distance still to travel drives the stretch.
    readonly property real _lag: _target - _pos
    readonly property real _stretch: Math.min(14, Math.abs(_lag) * 0.55)

    // Sunken well.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: Theme.sunken
    }

    // The travelling indicator. Extends along the direction of travel so the
    // motion reads as one shape flowing between slots, not a jump.
    Rectangle {
        id: indicator
        y: seg.pad
        x: seg._lag >= 0 ? seg._pos : seg._pos - seg._stretch
        width: seg.segWidth + seg._stretch
        height: seg.segHeight
        radius: height / 2
        antialiasing: true
        color: Theme.accent
    }

    Row {
        x: seg.pad
        y: seg.pad
        spacing: seg.spacing

        Repeater {
            model: seg.items
            delegate: Item {
                id: slot
                required property int index
                required property var modelData
                width: seg.segWidth
                height: seg.segHeight

                Text {
                    anchors.centerIn: parent
                    text: slot.modelData
                    color: slot.index === seg.currentIndex ? Theme.accentText : Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: seg.fontSize
                    font.weight: Font.DemiBold

                    Behavior on color {
                        ColorAnimation { duration: 140; easing.type: Config.easeFade }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: seg.interactive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.segmentClicked(slot.index)
                }
            }
        }
    }
}
